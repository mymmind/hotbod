import Foundation

struct PhysiqueIllustrationHints: Hashable, Sendable {
    var priorityMuscles: [PhysiqueFocusMuscle]
    var directionGenericLabels: [String]
}

struct PhysiqueIllustrationRecord: Codable, Hashable, Identifiable {
    var id: UUID { assessmentId }
    var assessmentId: UUID
    var sourcePhotoId: UUID
    var createdAt: Date
    var localImagePath: String
}
