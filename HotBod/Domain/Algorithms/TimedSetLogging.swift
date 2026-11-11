import Foundation

enum TimedSetLogging {
    /// Timed exercises that track real kilograms always show the weight field.
    static func showsAlwaysVisibleWeightField(for exercise: Exercise) -> Bool {
        switch exercise.resolvedPrescriptionType {
        case .time, .distanceOrTime:
            break
        case .reps, .distance:
            return false
        }
        guard exercise.resolvedLoadTrackingMode != .none else { return false }
        return exercise.resolvedWeightDisplaySemantics.tracksExternalKilograms
    }

    /// Empty draft means bodyweight (`nil`), even when a planned target exists.
    static func committedAddedLoad(draft: String?, plannedKg: Double?) -> CommittedLoggedLoad {
        guard let draft else {
            return CommittedLoggedLoad(weight: plannedKg, blocked: false)
        }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return CommittedLoggedLoad(weight: nil, blocked: false)
        }
        guard let value = Double(trimmed) else {
            return CommittedLoggedLoad(weight: nil, blocked: true)
        }
        return CommittedLoggedLoad(weight: value, blocked: false)
    }

    /// Display for timed added-load rows. `isCompleted` distinguishes a completed
    /// bodyweight set (`completedKg == nil`) from an incomplete set that should
    /// fall back to the planned kilograms. A present empty draft stays empty.
    static func displayedAddedLoadText(
        draft: String?,
        completedKg: Double?,
        plannedKg: Double?,
        isCompleted: Bool = false
    ) -> String {
        if let draft {
            if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "" }
            return draft
        }
        if isCompleted {
            if let completedKg {
                return WorkoutSessionMetricDrafts.formatWeightKg(completedKg)
            }
            return ""
        }
        if let completedKg {
            return WorkoutSessionMetricDrafts.formatWeightKg(completedKg)
        }
        if let plannedKg {
            return WorkoutSessionMetricDrafts.formatWeightKg(plannedKg)
        }
        return ""
    }
}
