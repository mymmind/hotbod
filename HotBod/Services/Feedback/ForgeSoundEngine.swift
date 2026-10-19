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

@MainActor
final class ForgeSoundEngine {
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var duckSession = ForgeDuckSession()
    private var chimeTask: Task<Void, Never>?

    func playTone(frequency: Double, duration: TimeInterval, volume: Float = 0.25) {
        guard duration > 0, frequency > 0 else { return }
        ensureReady()
        guard let engine, let playerNode else { return }
        if !engine.isRunning {
            try? engine.start()
        }

        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        guard sampleRate > 0 else { return }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: engine.mainMixerNode.outputFormat(forBus: 0),
            frameCapacity: frameCount
        ) else { return }

        buffer.frameLength = frameCount
        guard let channels = buffer.floatChannelData else { return }
        let channelCount = Int(buffer.format.channelCount)
        let totalFrames = Int(frameCount)

        for frame in 0..<totalFrames {
            let time = Double(frame) / sampleRate
            let envelope = min(1, time / 0.01) * min(1, (duration - time) / 0.04)
            let sample = Float(sin(2 * .pi * frequency * time) * envelope) * volume
            for channel in 0..<channelCount {
                channels[channel][frame] = sample
            }
        }

        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts) { }
        playerNode.play()
    }

    /// Two-note rest-complete chime played while other audio is ducked, then released.
    func playRestCompleteChime() {
        chimeTask?.cancel()
        let generation = duckSession.begin()
        rebuild()
        playTone(frequency: 440, duration: 0.16, volume: 0.9)
        chimeTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            self.playTone(frequency: 587, duration: 0.22, volume: 0.9)
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self.releaseDuck(generation: generation)
        }
    }

    private func ensureReady() {
        if engine == nil {
            rebuild()
        }
    }

    private func releaseDuck(generation: Int) {
        guard duckSession.end(generation: generation) else { return }
        engine?.stop()
        playerNode?.stop()
        engine = nil
        playerNode = nil
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        NotificationCenter.default.post(name: .forgeAudioDuckReleased, object: nil)
    }

    private func rebuild() {
        engine?.stop()
        playerNode?.stop()
        engine = nil
        playerNode = nil

        let session = AVAudioSession.sharedInstance()
        if duckSession.ducksOthers {
            try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        } else {
            try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        }
        try? session.setActive(true)

        let audioEngine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        audioEngine.attach(player)
        audioEngine.connect(player, to: audioEngine.mainMixerNode, format: nil)
        try? audioEngine.start()
        engine = audioEngine
        playerNode = player
    }
}
