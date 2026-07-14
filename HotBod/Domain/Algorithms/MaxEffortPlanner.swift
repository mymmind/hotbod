import Foundation

enum MaxEffortPlanner {
    static func shouldScheduleMaxEffort(stats: UserExerciseStats?, sessionMode: SessionMode) -> Bool {
        guard sessionMode == .standard else { return false }
        guard let stats, stats.planningWeightKg != nil else { return false }
        return stats.sessionsSinceMaxEffort >= GenerationConstants.MaxEffort.sessionsBetweenCalibration
    }

    static func markMaxEffortSet(in workingSets: inout [PlannedSet]) {
        guard !workingSets.isEmpty else { return }
        let index = workingSets.count - 1
        workingSets[index].isMaxEffort = true
    }

    static func recalibratedWeight(
        from completedSet: CompletedSet,
        equipment: [Equipment],
        ceilings: [Equipment: Double] = [:]
    ) -> Double? {
        guard let weight = completedSet.weightKg, completedSet.reps > 0 else { return nil }
        let e1rm = ProgressiveOverload.estimateOneRepMax(weight: weight, reps: completedSet.reps)
        let raw = e1rm * GenerationConstants.MaxEffort.workingWeightFraction
        return GenerationConstants.Weight.roundToAvailable(raw, equipment: equipment, ceilings: ceilings)
    }
}
