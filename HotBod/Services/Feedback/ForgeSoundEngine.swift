import AVFoundation

extension Notification.Name {
    /// Posted after the rest chime releases its duck and leaves the audio session inactive.
    static let forgeAudioDuckReleased = Notification.Name("hotbod.forgeAudioDuckReleased")
}

enum ForgeAudioCuePolicy {
    /// The rest-complete chime must duck other audio so it stays audible over music or a podcast.
    static func ducksOtherAudio(for event: ForgeFeedbackEvent) -> Bool {
        if case .restTimerEnd = event { return true }
        return false
    }
}

/// Tracks one rest-chime duck. A newer chime invalidates the previous release so ducking cannot stick on.
struct ForgeDuckSession: Equatable {
    private(set) var generation = 0
    private(set) var ducksOthers = false
    /// True while this chime should keep the playback session active.
    private(set) var holdsPlaybackSession = false

    mutating func begin() -> Int {
        generation += 1
        ducksOthers = true
        holdsPlaybackSession = true
        return generation
    }

    /// Ends ducking for `generation`. Stale generations are ignored.
    /// On success the engine must deactivate the session and leave it inactive.
    mutating func end(generation: Int) -> Bool {
        guard generation == self.generation, holdsPlaybackSession else { return false }
        ducksOthers = false
        holdsPlaybackSession = false
        return true
    }
}

/// `AVAudioPlayerNode.play()` and `stop()` raise ObjC exceptions — and abort the process —
/// unless the engine is running. `play()` also requires a real sample rate and channel count.
enum ForgePlaybackGate {
    static func canStartPlayer(engineIsRunning: Bool, sampleRate: Double, channelCount: Int) -> Bool {
        engineIsRunning && sampleRate.isFinite && sampleRate > 0 && channelCount > 0
    }

    static func canStopPlayer(engineIsRunning: Bool) -> Bool {
        engineIsRunning
    }
}

enum ForgeAudioSessionPolicy {
    /// Deactivating a session that already has the right category interrupts other audio and
    /// posts a configuration change that stops the engine we just started.
    static func needsCategoryChange(
        wantsDuck: Bool,
        category: AVAudioSession.Category,
        options: AVAudioSession.CategoryOptions
    ) -> Bool {
        if wantsDuck {
            return category != .playback || !options.contains(.duckOthers)
        }
        return category != .ambient || !options.contains(.mixWithOthers)
    }
}

enum ForgeToneSynthesizer {
    /// Requested connection format. The engine may negotiate a different rate;
    /// buffers are rendered in the player's format after start, never the output-node format.
    static let playbackFormat: AVAudioFormat = {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else {
            preconditionFailure("44.1 kHz mono is a valid PCM format")
        }
        return format
    }()

    static func makeBuffer(
        frequency: Double,
        duration: TimeInterval,
        volume: Float,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        guard duration > 0, frequency > 0 else { return nil }
        guard format.commonFormat == .pcmFormatFloat32 else { return nil }
        guard ForgePlaybackGate.canStartPlayer(
            engineIsRunning: true,
            sampleRate: format.sampleRate,
            channelCount: Int(format.channelCount)
        ) else { return nil }

        let frames = format.sampleRate * duration
        guard frames.isFinite, frames > 0, frames <= Double(AVAudioFrameCount.max) else { return nil }
        let frameCount = AVAudioFrameCount(frames)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              buffer.floatChannelData != nil else { return nil }

        buffer.frameLength = frameCount
        fill(buffer, frequency: frequency, duration: duration, volume: volume)
        return buffer
    }

    private static func fill(
        _ buffer: AVAudioPCMBuffer,
        frequency: Double,
        duration: TimeInterval,
        volume: Float
    ) {
        guard let channels = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let sampleRate = buffer.format.sampleRate
        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            let attack = min(1, time / 0.01)
            let release = min(1, (duration - time) / 0.04)
            let sample = Float(sin(2 * .pi * frequency * time) * attack * release) * volume
            for channel in 0..<channelCount {
                channels[channel][frame] = sample
            }
        }
    }
}

@MainActor
final class ForgeSoundEngine {
    private var duckSession = ForgeDuckSession()
    private var chimeTask: Task<Void, Never>?
    private var graphDucksOthers = false
    private nonisolated(unsafe) var engine: AVAudioEngine?
    private nonisolated(unsafe) var playerNode: AVAudioPlayerNode?
    private nonisolated(unsafe) var audioObservers: [any NSObjectProtocol] = []

    init() {
        audioObservers = [
            NotificationCenter.default.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.dropGraphAfterMediaReset()
                }
            }
        ]
    }

    func playTone(frequency: Double, duration: TimeInterval, volume: Float = 0.25) {
        _ = playCue(frequency: frequency, duration: duration, volume: volume)
    }

    /// Two-note rest-complete chime played while other audio is ducked, then released.
    func playRestCompleteChime() {
        chimeTask?.cancel()
        let generation = duckSession.begin()
        guard playCue(frequency: 440, duration: 0.16, volume: 0.9) else {
            releaseDuck(generation: generation)
            return
        }
        chimeTask = Task { @MainActor in
            defer { self.releaseDuck(generation: generation) }
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            guard self.playCue(frequency: 587, duration: 0.22, volume: 0.9) else { return }
            try? await Task.sleep(for: .milliseconds(400))
        }
    }

    nonisolated deinit {
        for observer in audioObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        if let engine, ForgePlaybackGate.canStopPlayer(engineIsRunning: engine.isRunning) {
            engine.stop()
        }
    }

    @discardableResult
    private func playCue(frequency: Double, duration: TimeInterval, volume: Float) -> Bool {
        guard duration > 0, frequency > 0 else { return false }
        guard let player = preparedPlayer(), let engine else { return false }
        let format = player.outputFormat(forBus: 0)
        guard player.engine === engine,
              ForgePlaybackGate.canStartPlayer(
                engineIsRunning: engine.isRunning,
                sampleRate: format.sampleRate,
                channelCount: Int(format.channelCount)
              ),
              let buffer = ForgeToneSynthesizer.makeBuffer(
                frequency: frequency,
                duration: duration,
                volume: volume,
                format: format
              ) else {
            dropGraph()
            releaseSessionIfNotDucking()
            return false
        }

        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        guard engine.isRunning else { return false }
        player.play()
        return true
    }

    private func preparedPlayer() -> AVAudioPlayerNode? {
        if graphDucksOthers == duckSession.ducksOthers, let engine, let playerNode {
            if playerFormatIsPlayable(playerNode, engine: engine) {
                return playerNode
            }
            if restart(engine), playerFormatIsPlayable(playerNode, engine: engine) {
                return playerNode
            }
        }
        guard rebuild() else { return nil }
        return playerNode
    }

    private func restart(_ engine: AVAudioEngine) -> Bool {
        if engine.isRunning { return true }
        do {
            try engine.start()
        } catch {
            return false
        }
        return engine.isRunning
    }

    private func playerFormatIsPlayable(_ player: AVAudioPlayerNode, engine: AVAudioEngine) -> Bool {
        let format = player.outputFormat(forBus: 0)
        return ForgePlaybackGate.canStartPlayer(
            engineIsRunning: engine.isRunning,
            sampleRate: format.sampleRate,
            channelCount: Int(format.channelCount)
        )
    }

    private func rebuild() -> Bool {
        dropGraph()
        guard activateSession() else { return false }

        let audioEngine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = ForgeToneSynthesizer.playbackFormat
        audioEngine.attach(player)
        audioEngine.connect(player, to: audioEngine.mainMixerNode, format: format)
        do {
            try audioEngine.start()
        } catch {
            releaseSessionIfNotDucking()
            return false
        }

        guard playerFormatIsPlayable(player, engine: audioEngine) else {
            if ForgePlaybackGate.canStopPlayer(engineIsRunning: audioEngine.isRunning) {
                audioEngine.stop()
            }
            releaseSessionIfNotDucking()
            return false
        }

        engine = audioEngine
        playerNode = player
        graphDucksOthers = duckSession.ducksOthers
        return true
    }

    private func activateSession() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            if ForgeAudioSessionPolicy.needsCategoryChange(
                wantsDuck: duckSession.ducksOthers,
                category: session.category,
                options: session.categoryOptions
            ) {
                // Category changes while the session is active fail, and the following play() aborts.
                try? session.setActive(false)
                if duckSession.ducksOthers {
                    try session.setCategory(.playback, mode: .default, options: [.duckOthers])
                } else {
                    try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                }
            }
            try session.setActive(true)
            return true
        } catch {
            return false
        }
    }

    private func releaseDuck(generation: Int) {
        guard duckSession.end(generation: generation) else { return }
        dropGraph()
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        NotificationCenter.default.post(name: .forgeAudioDuckReleased, object: nil)
    }

    private func releaseSessionIfNotDucking() {
        guard !duckSession.holdsPlaybackSession else { return }
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func dropGraph() {
        if let engine, ForgePlaybackGate.canStopPlayer(engineIsRunning: engine.isRunning) {
            engine.stop()
        }
        engine = nil
        playerNode = nil
        graphDucksOthers = false
    }

    /// Media Services reset invalidates the engine. Messaging it can throw; drop the references.
    private func dropGraphAfterMediaReset() {
        engine = nil
        playerNode = nil
        graphDucksOthers = false
    }
}
