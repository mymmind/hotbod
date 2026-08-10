import Foundation

enum PhysiqueFocusCopy {
    static func todayBiasLine(from assessment: PhysiqueAssessment, limit: Int = 3) -> String {
        let names = assessment.developmentPriorities.prefix(limit).map(\.muscle.displayName)
        return "Focus bias: " + names.joined(separator: ", ")
    }
}
