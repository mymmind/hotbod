import Foundation

enum SessionDurationBudget {
    struct Input {
        var planned: [PlannedExercise]
        var scores: [String: Double]
        var targetMuscles: [MuscleGroup]
        var exerciseMap: [String: Exercise]
        var targetDurationMinutes: Int
        var coreFinisherExerciseId: String?
        var conditioningExerciseId: String?
    }

    struct Result {
        var planned: [PlannedExercise]
        var removedCooldown: Bool
        var removedConditioning: Bool
        var removedCore: Bool
        var removedExtraWarmups: Bool
        var removedAccessory: Bool
    }

    static func apply(_ input: Input) -> Result {
        var planned = input.planned
        var removedCooldown = false
        var removedConditioning = false
        var removedCore = false
        var removedExtraWarmups = false
        var removedAccessory = false

        func over() -> Bool {
            WorkoutGenerationAlgorithms.estimateDurationMinutes(planned: planned) > input.targetDurationMinutes
        }
        func reindex() {
            for index in planned.indices { planned[index].orderIndex = index }
        }

        if over() {
            for index in planned.indices {
                let before = planned[index].targetSets.count
                planned[index].targetSets.removeAll(where: \.isCooldown)
                if planned[index].targetSets.count != before { removedCooldown = true }
            }
        }
        if over(), let conditioningId = input.conditioningExerciseId,
           let index = planned.firstIndex(where: { $0.exerciseId == conditioningId }) {
            planned.remove(at: index)
            removedConditioning = true
            reindex()
        }
        if over(), let coreId = input.coreFinisherExerciseId {
            while over(), let index = planned.firstIndex(where: { $0.exerciseId == coreId }) {
                if planned[index].targetSets.isEmpty {
                    planned.remove(at: index)
                    removedCore = true
                    reindex()
                    break
                }
                planned[index].targetSets.removeLast()
                removedCore = true
                if planned[index].targetSets.isEmpty {
                    planned.remove(at: index)
                    reindex()
                }
            }
        }
        if over(), let keeper = planned.firstIndex(where: { $0.targetSets.contains(where: \.isWarmup) }) {
            for index in planned.indices where index != keeper {
                let before = planned[index].targetSets.count
                planned[index].targetSets.removeAll(where: \.isWarmup)
                if planned[index].targetSets.count != before { removedExtraWarmups = true }
            }
        }
        while over() {
            guard let drop = WorkoutGenerationAlgorithms.indexOfLowestScoredIsolationToDrop(
                planned: planned,
                scores: input.scores,
                targetMuscles: input.targetMuscles,
                exerciseMap: input.exerciseMap
            ) else { break }
            let exerciseId = planned[drop].exerciseId
            if exerciseId == input.coreFinisherExerciseId || exerciseId == input.conditioningExerciseId {
                break
            }
            guard input.exerciseMap[exerciseId]?.resolvedMechanics != .compound else { break }
            planned.remove(at: drop)
            removedAccessory = true
            reindex()
        }

        return Result(
            planned: planned,
            removedCooldown: removedCooldown,
            removedConditioning: removedConditioning,
            removedCore: removedCore,
            removedExtraWarmups: removedExtraWarmups,
            removedAccessory: removedAccessory
        )
    }

    static func rationaleSuffix(
        removedCooldown: Bool,
        removedConditioning: Bool,
        removedCore: Bool,
        removedExtraWarmups: Bool,
        removedAccessory: Bool,
        targetMinutes: Int,
        estimatedMinutes: Int
    ) -> String? {
        var parts: [String] = []
        if removedCooldown { parts.append("cooldown") }
        if removedConditioning { parts.append("conditioning") }
        if removedCore { parts.append("core finisher") }
        if removedExtraWarmups { parts.append("extra warm-ups") }
        if removedAccessory { parts.append("accessory work") }
        var sentences: [String] = []
        if !parts.isEmpty {
            sentences.append("Adjusted to fit \(targetMinutes) min by removing \(joined(parts)).")
        }
        if estimatedMinutes > targetMinutes {
            sentences.append("Estimated \(estimatedMinutes) min. Priority work exceeds the \(targetMinutes) min target.")
        }
        guard !sentences.isEmpty else { return nil }
        return sentences.joined(separator: " ")
    }

    private static func joined(_ parts: [String]) -> String {
        switch parts.count {
        case 0: return ""
        case 1: return parts[0]
        case 2: return "\(parts[0]) and \(parts[1])"
        default:
            let head = parts.dropLast().joined(separator: ", ")
            return "\(head), and \(parts.last ?? "")"
        }
    }
}
