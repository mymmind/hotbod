import Foundation

enum HoldCommitOutcome: Equatable {
    case commit(seconds: Int)
    case cancel
}

enum HoldTargetResolution: Equatable {
    case seconds(Int)
    case blocked
}

enum HoldCountdownTarget {
    /// Resolves the countdown target from a typed draft, planned seconds, then the exercise default.
    /// A non-empty draft that is not a positive integer blocks Start.
    static func resolve(
        draft: String?,
        plannedSeconds: Int?,
        exerciseDefault: Int
    ) -> HoldTargetResolution {
        if let draft {
            let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                guard let value = Int(trimmed), value > 0 else { return .blocked }
                return .seconds(value)
            }
        }

        if let plannedSeconds, plannedSeconds > 0 {
            return .seconds(plannedSeconds)
        }
        if exerciseDefault > 0 {
            return .seconds(exerciseDefault)
        }
        return .blocked
    }
}

struct HoldCountdown: Equatable {
    let plannedSetId: UUID
    let workoutExerciseId: UUID
    let setIndex: Int
    let targetSeconds: Int
    let endsAt: Date

    static func starting(
        plannedSetId: UUID,
        workoutExerciseId: UUID,
        setIndex: Int,
        targetSeconds: Int,
        at now: Date = Date()
    ) -> HoldCountdown {
        HoldCountdown(
            plannedSetId: plannedSetId,
            workoutExerciseId: workoutExerciseId,
            setIndex: setIndex,
            targetSeconds: targetSeconds,
            endsAt: now.addingTimeInterval(TimeInterval(targetSeconds))
        )
    }

    func remaining(at now: Date = Date()) -> Int {
        WorkoutSessionCalculator.restSecondsRemaining(until: endsAt, at: now)
    }

    func elapsed(at now: Date = Date()) -> Int {
        max(0, targetSeconds - remaining(at: now))
    }

    func outcome(at now: Date = Date()) -> HoldCommitOutcome {
        let remainingSeconds = remaining(at: now)
        if remainingSeconds == 0 {
            return .commit(seconds: targetSeconds)
        }
        let held = elapsed(at: now)
        if held == 0 {
            return .cancel
        }
        return .commit(seconds: held)
    }
}
