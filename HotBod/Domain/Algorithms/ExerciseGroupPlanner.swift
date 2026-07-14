import Foundation

enum ExerciseGroupingPreference: String, Codable, CaseIterable, Hashable {
    case none
    case supersets
    case circuits

    var displayName: String {
        switch self {
        case .none: "Off"
        case .supersets: "Supersets"
        case .circuits: "Circuits"
        }
    }
}

enum ExerciseVariabilityLevel: String, Codable, CaseIterable, Hashable {
    case consistent
    case balanced
    case varied

    var displayName: String {
        switch self {
        case .consistent: "Consistent"
        case .balanced: "Balanced"
        case .varied: "Varied"
        }
    }

    var jitterMultiplier: Double {
        switch self {
        case .consistent: 0
        case .balanced: 1.0
        case .varied: 2.0
        }
    }

    var appliesJitter: Bool { jitterMultiplier > 0 }
}

enum ExerciseGroupPlanner {
    static func applyGrouping(
        to planned: inout [PlannedExercise],
        preference: ExerciseGroupingPreference,
        exerciseMap: [String: Exercise]
    ) {
        guard preference != .none, planned.count >= 2 else { return }

        let targetSize = preference == .supersets
            ? GenerationConstants.Grouping.supersetSize
            : GenerationConstants.Grouping.circuitSize
        var index = 0

        while index < planned.count {
            guard planned[index].groupId == nil else {
                index += 1
                continue
            }

            var members = [index]
            var cursor = index + 1
            while members.count < targetSize, cursor < planned.count, planned[cursor].groupId == nil {
                guard let anchor = exerciseMap[planned[members.last!].exerciseId],
                      let candidate = exerciseMap[planned[cursor].exerciseId],
                      areCompatibleForGrouping(anchor, candidate) else { break }
                members.append(cursor)
                cursor += 1
            }

            if members.count >= 2 {
                let groupId = UUID()
                for member in members {
                    planned[member].groupId = groupId
                }
                index = members.last! + 1
            } else {
                index += 1
            }
        }
    }

    static func areCompatibleForGrouping(_ lhs: Exercise, _ rhs: Exercise) -> Bool {
        let shared = Set(lhs.primaryMuscles).intersection(Set(rhs.primaryMuscles))
        if shared.isEmpty { return true }
        return lhs.resolvedMechanics == .isolation || rhs.resolvedMechanics == .isolation
    }

    static func groupAdjacent(in exercises: inout [WorkoutExercise], at index: Int) {
        guard exercises.indices.contains(index),
              index + 1 < exercises.count else { return }
        let groupId = exercises[index].groupId
            ?? exercises[index + 1].groupId
            ?? UUID()
        exercises[index].groupId = groupId
        exercises[index + 1].groupId = groupId
    }

    static func ungroup(in exercises: inout [WorkoutExercise], at index: Int) {
        guard let groupId = exercises[index].groupId else { return }
        for idx in exercises.indices where exercises[idx].groupId == groupId {
            exercises[idx].groupId = nil
        }
    }

    static func contextLabel(
        for exercises: [WorkoutExercise],
        exercise: WorkoutExercise,
        exerciseMap: [String: Exercise],
        groupingPreference: ExerciseGroupingPreference = .none
    ) -> String? {
        guard let groupId = exercise.groupId else { return nil }
        let members = exercises
            .filter { $0.groupId == groupId }
            .sorted { $0.orderIndex < $1.orderIndex }
        guard members.count >= 2 else { return nil }

        let kind: String
        switch groupingPreference {
        case .circuits: kind = "Circuit"
        case .supersets: kind = "Superset"
        case .none: kind = members.count == 2 ? "Superset" : "Circuit"
        }
        let names = members.compactMap { exerciseMap[$0.exerciseId]?.name }
        guard names.count >= 2 else { return kind }
        return "\(kind) · \(names.joined(separator: " + "))"
    }

    static func restBeforeAdvancing(from index: Int, exercises: [WorkoutExercise]) -> Int {
        guard exercises.indices.contains(index), index + 1 < exercises.count else { return 0 }
        let current = exercises[index]
        let next = exercises[index + 1]

        if let groupId = current.groupId, groupId == next.groupId {
            return GenerationConstants.Grouping.transitionRestSeconds
        }
        if let groupId = current.groupId {
            return groupRestSeconds(for: groupId, in: exercises)
        }
        return 0
    }

    static func groupRestSeconds(for groupId: UUID, in exercises: [WorkoutExercise]) -> Int {
        exercises
            .filter { $0.groupId == groupId }
            .map(\.restSeconds)
            .max()
            ?? GenerationConstants.Grouping.defaultGroupRestSeconds
    }
}
