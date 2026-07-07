import Foundation

/// Metadata for a Fitbod-style swap family — exercises in the same group fill the same workout slot.
struct ExerciseSubstitutionGroup: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var primaryMuscles: [MuscleGroup]
    var movementPattern: MovementPattern
    var description: String?
    /// Optional explicit roster; runtime index is built from exercise `substitutionGroupId` values.
    var exerciseIds: [String] = []
}

/// Per-exercise content you can populate in `ExerciseContent.json` (merged onto seed catalog).
struct ExerciseContentEntry: Codable, Hashable {
    var aliases: [String]?
    var instructions: [String]?
    var formCues: [String]?
    var commonMistakes: [String]?
    var substitutionGroupId: String?
    var substitutions: [String]?
    var description: String?
}

struct ExerciseContentBundle: Codable {
    var substitutionGroups: [ExerciseSubstitutionGroup] = []
    var exercises: [String: ExerciseContentEntry] = [:]
}
