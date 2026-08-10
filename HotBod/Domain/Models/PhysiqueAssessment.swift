import Foundation

struct PhysiquePhotoQuality: Codable, Hashable {
    var anglesAvailable: [String]
    var lightingQuality: String
    var overallConfidence: Double
}

struct PhysiqueBuildSummary: Codable, Hashable {
    var overallArchetype: String
    var frameSize: String
    var shoulderToWaist: String
    var waist: String
    var torso: String
    var muscularity: String
    var leanness: String
}

struct PhysiqueMuscleEntry: Codable, Hashable {
    var muscle: PhysiqueFocusMuscle
    var current: String
    var priorityRank: Int?
    var notes: String
    var confidence: PhysiqueObservationConfidence
}

struct PhysiqueDevelopmentPriority: Codable, Hashable {
    var muscle: PhysiqueFocusMuscle
    var reason: String
}

struct PhysiqueTrainingBias: Codable, Hashable {
    var preferredMuscleGroups: [MuscleGroup]
    var rationale: String
}

struct PhysiqueConfidenceBands: Codable, Hashable {
    var high: [String]
    var medium: [String]
    var low: [String]
}

struct PhysiqueAssessment: Identifiable, Codable, Hashable {
    let id: UUID
    var createdAt: Date
    var frontPhotoId: UUID
    var backPhotoId: UUID
    var sidePhotoId: UUID?
    var photoQuality: PhysiquePhotoQuality
    var physique: PhysiqueBuildSummary
    var muscleEntries: [PhysiqueMuscleEntry]
    var developmentPriorities: [PhysiqueDevelopmentPriority]
    var trainingBias: PhysiqueTrainingBias
    var limitations: [String]
    var confidenceBands: PhysiqueConfidenceBands
    var source: PhysiqueAssessmentSource
    var whyTodaySummary: String
}
