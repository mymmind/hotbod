import CoreHaptics
import UIKit

struct HapticPulseEvent {
    let time: TimeInterval
    let intensity: Float
    let sharpness: Float
}

@MainActor
final class ForgeHapticEngine {
    private var supportsCoreHaptics: Bool
    private var engine: CHHapticEngine?

    init() {
        supportsCoreHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        if supportsCoreHaptics {
            engine = try? CHHapticEngine()
            engine?.playsHapticsOnly = true
            engine?.stoppedHandler = { [weak self] _ in
                Task { @MainActor in self?.restartEngineIfNeeded() }
            }
            engine?.resetHandler = { [weak self] in
                Task { @MainActor in self?.restartEngineIfNeeded() }
            }
            try? engine?.start()
        }
    }

    func prepare() {
        try? engine?.start()
    }

    func playRestWarning() {
        if playPattern(events: [
            HapticPulseEvent(time: 0, intensity: 0.35, sharpness: 0.2)
        ]) { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
    }

    func playRestEnd() {
        if playPattern(events: [
            HapticPulseEvent(time: 0, intensity: 0.75, sharpness: 0.55),
            HapticPulseEvent(time: 0.12, intensity: 0.45, sharpness: 0.25)
        ]) { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func playLightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.75)
    }

    func playSelection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func playSuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func playWarning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    func playError() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    func playIncrease() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.65)
    }

    private func playPattern(events: [HapticPulseEvent]) -> Bool {
        guard supportsCoreHaptics, let engine else { return false }
        let hapticEvents = events.map { event in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: event.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: event.sharpness)
                ],
                relativeTime: event.time
            )
        }
        guard let pattern = try? CHHapticPattern(events: hapticEvents, parameters: []) else { return false }
        let player = try? engine.makePlayer(with: pattern)
        try? player?.start(atTime: CHHapticTimeImmediate)
        return true
    }

    private func restartEngineIfNeeded() {
        try? engine?.start()
    }
}
