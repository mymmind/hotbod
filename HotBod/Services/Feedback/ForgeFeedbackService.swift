import SwiftUI

enum ForgeFeedbackEvent: Equatable {
    case setComplete
    case personalRecord
    case restTimerStart
    case restTimerWarning
    case restTimerCountdown(second: Int)
    case restTimerEnd(kind: RestTimerEndKind)
    case exerciseComplete
    case workoutComplete
    case proteinAdded
    case tabSelection
    case buttonPress
    case selection
    case success
    case warning
    case error
    case increase
    case coachApply
    case exerciseSwap
    case workoutRegenerate
}

@MainActor
@Observable
final class ForgeFeedbackService {
    var hapticsEnabled: Bool {
        didSet { ForgeFeedbackPreferences.hapticsEnabled = hapticsEnabled }
    }

    var soundsEnabled: Bool {
        didSet { ForgeFeedbackPreferences.soundsEnabled = soundsEnabled }
    }

    private let haptics = ForgeHapticEngine()
    private let sounds = ForgeSoundEngine()

    init() {
        if UITestConfiguration.isUITesting {
            hapticsEnabled = false
            soundsEnabled = false
        } else {
            hapticsEnabled = ForgeFeedbackPreferences.hapticsEnabled
            soundsEnabled = ForgeFeedbackPreferences.soundsEnabled
        }
    }

    var allowsHaptics: Bool {
        hapticsEnabled && !UIAccessibility.isReduceMotionEnabled
    }

    func play(_ event: ForgeFeedbackEvent) {
        guard !UITestConfiguration.isUITesting else { return }
        if allowsHaptics {
            playHaptic(event)
        }
        if soundsEnabled {
            playSound(event)
        }
    }

    func prepare(for event: ForgeFeedbackEvent) {
        guard allowsHaptics else { return }
        switch event {
        case .restTimerEnd(_), .restTimerWarning, .restTimerCountdown:
            haptics.prepare()
        default:
            break
        }
    }

    private func playHaptic(_ event: ForgeFeedbackEvent) {
        switch event {
        case .setComplete, .buttonPress:
            haptics.playLightImpact()
        case .personalRecord, .workoutComplete, .coachApply, .success:
            haptics.playSuccess()
        case .restTimerStart:
            haptics.playSelection()
        case .restTimerWarning:
            haptics.playRestWarning()
        case let .restTimerCountdown(second):
            if second == 1 {
                haptics.playLightImpact()
            } else {
                haptics.playSelection()
            }
        case let .restTimerEnd(kind):
            switch kind {
            case .setRest:
                haptics.playRestEnd()
            case .transition:
                haptics.playIncrease()
            }
        case .exerciseComplete:
            haptics.playIncrease()
        case .proteinAdded, .increase:
            haptics.playIncrease()
        case .tabSelection, .selection, .exerciseSwap:
            haptics.playSelection()
        case .warning, .workoutRegenerate:
            haptics.playWarning()
        case .error:
            haptics.playError()
        }
    }

    private func playSound(_ event: ForgeFeedbackEvent) {
        switch event {
        case .setComplete:
            sounds.playTone(frequency: 880, duration: 0.06, volume: 0.18)
        case .personalRecord:
            sounds.playTone(frequency: 660, duration: 0.08, volume: 0.2)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(90))
                sounds.playTone(frequency: 990, duration: 0.12, volume: 0.22)
            }
        case .restTimerWarning:
            sounds.playTone(frequency: 520, duration: 0.08, volume: 0.16)
        case let .restTimerCountdown(second):
            let step = Float(6 - second)
            sounds.playTone(
                frequency: 480 + Double(step) * 35,
                duration: 0.05,
                volume: 0.14 + step * 0.02
            )
        case let .restTimerEnd(kind):
            switch kind {
            case .setRest:
                sounds.playTone(frequency: 440, duration: 0.14, volume: 0.2)
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(150))
                    sounds.playTone(frequency: 587, duration: 0.18, volume: 0.18)
                }
            case .transition:
                sounds.playTone(frequency: 784, duration: 0.1, volume: 0.22)
            }
        case .exerciseComplete:
            sounds.playTone(frequency: 620, duration: 0.07, volume: 0.16)
        case .workoutComplete:
            sounds.playTone(frequency: 330, duration: 0.2, volume: 0.22)
        case .proteinAdded:
            sounds.playTone(frequency: 740, duration: 0.05, volume: 0.14)
        case .error:
            sounds.playTone(frequency: 220, duration: 0.1, volume: 0.18)
        case .coachApply, .success:
            sounds.playTone(frequency: 587, duration: 0.1, volume: 0.16)
        default:
            break
        }
    }
}

private struct ForgeFeedbackServiceKey: EnvironmentKey {
    static var defaultValue: ForgeFeedbackService {
        MainActor.assumeIsolated {
            ForgeFeedbackService()
        }
    }
}

extension EnvironmentValues {
    var forgeFeedback: ForgeFeedbackService {
        get { self[ForgeFeedbackServiceKey.self] }
        set { self[ForgeFeedbackServiceKey.self] = newValue }
    }
}
