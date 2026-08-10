import Foundation

struct PhysiqueBuildFieldChange: Hashable {
    var field: String
    var from: String
    var to: String
}

struct PhysiquePriorityChanges: Hashable {
    var added: [PhysiqueFocusMuscle]
    var removed: [PhysiqueFocusMuscle]
    var reordered: Bool
}

struct PhysiqueDirectionChanges: Hashable {
    var added: [String]
    var removed: [String]
}

struct PhysiqueAssessmentDiff: Hashable {
    var previousId: UUID
    var currentId: UUID
    var previousDate: Date
    var currentDate: Date
    var buildChanges: [PhysiqueBuildFieldChange]
    var priorityChanges: PhysiquePriorityChanges
    var directionChanges: PhysiqueDirectionChanges
    var visionTrends: [String]
    var summaryLines: [String]
    var hasMeaningfulChange: Bool
}
