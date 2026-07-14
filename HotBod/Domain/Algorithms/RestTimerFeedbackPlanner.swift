import Foundation

enum RestTimerFeedbackCue: Hashable {
    case tenSecondWarning
    case countdown(second: Int)
}

enum RestTimerKind: Equatable {
    case setRest
    case transitionRest
}

enum RestTimerEndKind: Equatable {
    case setRest
    case transition
}

enum RestTimerFeedbackPlanner {
    static let warningSecond = 10
    static let countdownSeconds = [5, 4, 3, 2, 1]
    /// Only cue the final five seconds on rests long enough to matter in the gym.
    static let minimumRestForCountdown = 30

    static func timerKind(advancesExercise: Bool, totalSeconds: Int) -> RestTimerKind {
        if advancesExercise,
           totalSeconds <= GenerationConstants.Grouping.transitionRestSeconds {
            return .transitionRest
        }
        return .setRest
    }

    static func endKind(for timerKind: RestTimerKind) -> RestTimerEndKind {
        timerKind == .transitionRest ? .transition : .setRest
    }

    /// Returns the next cue to fire for the current tick, if any.
    static func pendingCue(
        secondsRemaining: Int,
        totalSeconds: Int,
        timerKind: RestTimerKind,
        played: Set<RestTimerFeedbackCue>
    ) -> RestTimerFeedbackCue? {
        guard timerKind == .setRest else { return nil }

        if secondsRemaining == warningSecond, !played.contains(.tenSecondWarning) {
            return .tenSecondWarning
        }
        if totalSeconds >= minimumRestForCountdown,
           countdownSeconds.contains(secondsRemaining),
           !played.contains(.countdown(second: secondsRemaining)) {
            return .countdown(second: secondsRemaining)
        }
        return nil
    }

    /// Marks cues that were skipped while the app was inactive so they are not replayed.
    static func cuesToMarkSkipped(
        afterResumingWith secondsRemaining: Int,
        totalSeconds: Int,
        timerKind: RestTimerKind
    ) -> Set<RestTimerFeedbackCue> {
        guard timerKind == .setRest else { return [] }

        var skipped = Set<RestTimerFeedbackCue>()
        if secondsRemaining < warningSecond {
            skipped.insert(.tenSecondWarning)
        }
        if totalSeconds >= minimumRestForCountdown {
            for second in countdownSeconds where second > secondsRemaining {
                skipped.insert(.countdown(second: second))
            }
        }
        return skipped
    }
}
