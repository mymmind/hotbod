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
}
