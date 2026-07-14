import AVFoundation

final class ForgeSoundEngine: @unchecked Sendable {
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var isConfigured = false

    func playTone(frequency: Double, duration: TimeInterval, volume: Float = 0.25) {
        guard duration > 0, frequency > 0 else { return }
        configureIfNeeded()
        guard let engine, let playerNode else { return }

        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
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

        if !engine.isRunning {
            try? engine.start()
        }
        playerNode.stop()
        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts) { }
        playerNode.play()
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: engine.mainMixerNode.outputFormat(forBus: 0))
        self.engine = engine
        self.playerNode = player
    }
}
