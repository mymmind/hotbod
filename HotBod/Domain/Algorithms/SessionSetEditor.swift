import Foundation

enum SessionSetEditor {
    /// Builds an extra in-session set from the last planned set.
    /// Always mints a fresh `id` so SwiftUI `ForEach` and draft dictionaries stay unique.
    static func additionalSet(copying last: PlannedSet?) -> PlannedSet {
        guard let last else {
            return PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        }
        return PlannedSet(
            targetRepsMin: last.targetRepsMin,
            targetRepsMax: last.targetRepsMax,
            targetWeightKg: last.targetWeightKg,
            rpeTarget: last.rpeTarget,
            targetDurationSeconds: last.targetDurationSeconds,
            targetDistanceMeters: last.targetDistanceMeters,
            isWarmup: false,
            isMaxEffort: false,
            isCooldown: false
        )
    }
}
