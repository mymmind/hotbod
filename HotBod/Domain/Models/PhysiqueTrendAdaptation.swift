import Foundation

struct PhysiqueTrendAdaptation: Codable, Hashable {
    var previousAssessmentId: UUID
    var reasons: [String]
}
