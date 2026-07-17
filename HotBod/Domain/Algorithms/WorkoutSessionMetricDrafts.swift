import Foundation

/// Persists in-progress set metric drafts onto incomplete planned sets.
/// Drafts live in the session UI as string maps; this flushes parseable values
/// into `WorkoutSession` so pause/resume and process death keep the user's edits.
enum WorkoutSessionMetricDrafts {
    /// Returns a copy of `session` with incomplete planned sets updated from draft texts.
    /// - Only touches sets that are not yet completed (`setIndex >= completedSets.count`).
    /// - Ignores blank or unparseable draft strings (keeps existing planned values).
    static func applying(
        to session: WorkoutSession,
        weightTexts: [UUID: String],
        repsTexts: [UUID: String],
        durationTexts: [UUID: String] = [:],
        distanceTexts: [UUID: String] = [:]
    ) -> WorkoutSession {
        var updated = session
        for exerciseIndex in updated.exercises.indices {
            let completedCount = updated.exercises[exerciseIndex].completedSets.count
            let plannedCount = updated.exercises[exerciseIndex].plannedSets.count
            guard completedCount < plannedCount else { continue }

            for setIndex in completedCount..<plannedCount {
                let plannedId = updated.exercises[exerciseIndex].plannedSets[setIndex].id

                if let text = weightTexts[plannedId], let weight = Double(text) {
                    updated.exercises[exerciseIndex].plannedSets[setIndex].targetWeightKg = weight
                }
                if let text = repsTexts[plannedId], let reps = Int(text) {
                    updated.exercises[exerciseIndex].plannedSets[setIndex].targetRepsMin = reps
                    if updated.exercises[exerciseIndex].plannedSets[setIndex].targetRepsMax < reps {
                        updated.exercises[exerciseIndex].plannedSets[setIndex].targetRepsMax = reps
                    }
                }
                if let text = durationTexts[plannedId], let seconds = Int(text) {
                    updated.exercises[exerciseIndex].plannedSets[setIndex].targetDurationSeconds = seconds
                }
                if let text = distanceTexts[plannedId], let meters = Double(text) {
                    updated.exercises[exerciseIndex].plannedSets[setIndex].targetDistanceMeters = meters
                }
            }
        }
        return updated
    }

    /// Formats weight for set-input display, preserving half-kilogram precision.
    static func formatWeightKg(_ kg: Double) -> String {
        if kg.rounded() == kg {
            return String(format: "%.0f", kg)
        }
        return String(format: "%.1f", kg)
    }

    /// Resolves the string shown in a set weight field.
    /// - Non-empty drafts win (including in-progress sanity-warning edits).
    /// - Blank drafts must not block completed/planned fallbacks.
    /// - Completed values outrank planned targets so a finished set cannot
    ///   visually revert when another set is edited.
    static func displayedWeightText(
        draft: String?,
        completedKg: Double?,
        plannedKg: Double?
    ) -> String {
        if let draft, !draft.isEmpty { return draft }
        if let completedKg { return formatWeightKg(completedKg) }
        if let plannedKg { return formatWeightKg(plannedKg) }
        return ""
    }

    /// Resolves the string shown in a set reps field.
    static func displayedRepsText(
        draft: String?,
        completedReps: Int?,
        plannedRepsMin: Int
    ) -> String {
        if let draft, !draft.isEmpty { return draft }
        if let completedReps { return String(completedReps) }
        return String(plannedRepsMin)
    }

    /// Resolves the string shown in a set duration field.
    static func displayedDurationText(
        draft: String?,
        completedSeconds: Int?,
        plannedSeconds: Int?
    ) -> String {
        if let draft, !draft.isEmpty { return draft }
        if let completedSeconds { return String(completedSeconds) }
        if let plannedSeconds { return String(plannedSeconds) }
        return ""
    }

    /// Resolves the string shown in a set distance field.
    static func displayedDistanceText(
        draft: String?,
        completedMeters: Double?,
        plannedMeters: Double?
    ) -> String {
        if let draft, !draft.isEmpty { return draft }
        if let completedMeters { return String(format: "%.0f", completedMeters) }
        if let plannedMeters { return String(format: "%.0f", plannedMeters) }
        return ""
    }
}
