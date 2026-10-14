import Foundation

enum EffortFeedbackMapping {
    /// Maps logged RIR (0 = failure, 4 = 3+ reps left) to an approximate RPE.
    static func rpe(fromRIR rir: Int) -> Double {
        let clamped = min(max(rir, 0), 4)
        if clamped >= 4 { return 7.0 }
        return Double(10 - clamped)
    }

    /// Derives RIR from RPE when only RPE was logged.
    static func rir(fromRPE rpe: Double) -> Int {
        let repsLeft = Int((10 - rpe).rounded())
        return min(max(repsLeft, 0), 4)
    }

    /// Effective RPE for progression: prefer RIR when both exist (RIR is the post-set truth).
    static func effectiveRPE(rpe: Double?, rir: Int?) -> Double? {
        if let rir { return Self.rpe(fromRIR: rir) }
        if let rpe { return rpe }
        return nil
    }

    static func trustedEffectiveRPE(
        rpe: Double?,
        rir: Int?,
        status: EffortFeedbackStatus,
        trustHistoric: Bool
    ) -> Double? {
        switch status {
        case .explicit:
            return effectiveRPE(rpe: rpe, rir: rir)
        case .skipped:
            return nil
        case .unknown:
            guard trustHistoric else { return nil }
            return effectiveRPE(rpe: rpe, rir: rir)
        }
    }

    static func markSkipped(_ set: inout CompletedSet) {
        set.effortFeedbackStatus = .skipped
        set.rir = nil
        set.rpe = nil
        set.isFailure = false
    }

    static func markExplicit(_ set: inout CompletedSet, rir: Int) {
        set.effortFeedbackStatus = .explicit
        set.rir = rir
        set.rpe = rpe(fromRIR: rir)
        set.isFailure = rir == 0
    }

    static func applyCommitEffort(_ set: inout CompletedSet, loggedRPE: Double?) {
        if let loggedRPE {
            set.rpe = loggedRPE
            set.effortFeedbackStatus = .explicit
        } else {
            markSkipped(&set)
        }
    }

    static func recordEditedRPE(_ set: inout CompletedSet, rpe: Double) {
        set.rpe = rpe
        set.effortFeedbackStatus = .explicit
    }

    static func isWorkingSet(_ set: CompletedSet) -> Bool {
        !set.isWarmup && !set.isCooldown
            && (set.reps > 0 || (set.durationSeconds ?? 0) > 0 || (set.distanceMeters ?? 0) > 0)
    }

    static func averageEffectiveRPE(
        from sets: [CompletedSet],
        trustHistoric: Bool = true
    ) -> Double? {
        let working = sets.filter(isWorkingSet)
        guard !working.isEmpty else { return nil }
        let values = working.compactMap {
            trustedEffectiveRPE(
                rpe: $0.rpe, rir: $0.rir, status: $0.effortFeedbackStatus, trustHistoric: trustHistoric
            )
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    static func metPrescription(
        completed: CompletedSet,
        planned: PlannedSet
    ) -> (hitTop: Bool, missedMin: Bool) {
        if let targetSeconds = planned.targetDurationSeconds, targetSeconds > 0 {
            let actual = completed.durationSeconds ?? 0
            return (actual >= targetSeconds, actual < max(1, targetSeconds - 5))
        }
        if let targetMeters = planned.targetDistanceMeters, targetMeters > 0 {
            let actual = completed.distanceMeters ?? 0
            return (actual >= targetMeters, actual < targetMeters * 0.9)
        }
        if planned.isMaxEffort {
            return (completed.reps >= planned.targetRepsMin, completed.reps < planned.targetRepsMin)
        }
        return (
            completed.reps >= planned.targetRepsMax,
            completed.reps < planned.targetRepsMin
        )
    }
}
