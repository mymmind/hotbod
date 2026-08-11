import Foundation

enum PhysiqueSplitSuggestionPreferences {
    private static let key = "hotbod.physique.splitSuggestion.dismissedAssessmentId"

    static var dismissedAssessmentId: UUID? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.uuidString, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    static func markHandled(assessmentId: UUID) {
        dismissedAssessmentId = assessmentId
    }

    static func clear() {
        dismissedAssessmentId = nil
    }
}
