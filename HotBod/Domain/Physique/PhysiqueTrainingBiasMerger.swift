import Foundation

enum PhysiqueTrainingBiasMerger {
    static func mergePreferredMuscleGroups(
        profilePreferred: [MuscleGroup],
        assessmentBias: [MuscleGroup],
        avoided: [MuscleGroup]
    ) -> [MuscleGroup] {
        let avoidedSet = Set(avoided)
        var seen = Set<MuscleGroup>()
        var merged: [MuscleGroup] = []

        for group in assessmentBias + profilePreferred {
            guard !avoidedSet.contains(group), !seen.contains(group) else { continue }
            seen.insert(group)
            merged.append(group)
        }

        return merged
    }

    static func preferredGroups(from priorities: [PhysiqueFocusMuscle]) -> [MuscleGroup] {
        var seen = Set<MuscleGroup>()
        var groups: [MuscleGroup] = []

        for muscle in priorities {
            for group in muscle.muscleGroups {
                guard !seen.contains(group) else { continue }
                seen.insert(group)
                groups.append(group)
            }
        }

        return groups
    }
}
