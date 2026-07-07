import Foundation

/// Determines whether an AI-proposed workout modification is safe to auto-apply
/// without explicit user confirmation.
enum CoachModificationSafety {
    static func isSafeModification(
        proposed: GeneratedWorkout,
        current: GeneratedWorkout?,
        allowedExerciseIds: Set<String>
    ) -> Bool {
        guard let current else { return false }

        for exercise in proposed.exercises {
            if !allowedExerciseIds.contains(exercise.exerciseId) {
                return false
            }
        }

        if proposed.estimatedDurationMinutes > current.estimatedDurationMinutes {
            return false
        }

        let currentSets = VolumeCalculator.totalSets(exercises: current.exercises)
        let proposedSets = VolumeCalculator.totalSets(exercises: proposed.exercises)
        let maxSets = Int(ceil(Double(currentSets) * 1.2))
        if proposedSets > maxSets {
            return false
        }

        return true
    }
}

enum CoachOfflineModify {
    static func generationOptions(from message: String, profile: UserProfile) -> WorkoutGenerationOptions {
        var options = WorkoutGenerationOptions()
        let lower = message.lowercased()

        if lower.contains("30") {
            options.targetDurationMinutes = 30
        } else if lower.contains("45") {
            options.targetDurationMinutes = 45
        } else if lower.contains("60") {
            options.targetDurationMinutes = 60
        } else if lower.contains("shorter") || lower.contains("faster") || lower.contains("quick") || lower.contains("less time") {
            options.targetDurationMinutes = max(20, profile.preferredSessionLengthMinutes - 15)
        }

        if lower.contains("shoulder") || lower.contains("sketchy") || lower.contains("hurt") || lower.contains("pain") {
            options.soreness = .moderate
        }
        if lower.contains("severe") || lower.contains("really sore") {
            options.soreness = .severe
        }

        if lower.contains("lighter") || lower.contains("easier") {
            options.soreness = options.soreness ?? .mild
        }

        return options
    }

    static func restDayMessage(profile: UserProfile) -> String? {
        guard !TrainingSchedule.isTrainingDay(profile: profile) else { return nil }
        if let next = TrainingSchedule.nextTrainingDayLabel(profile: profile) {
            return "Today is a rest day. Next session: \(next)."
        }
        return "Today is a rest day."
    }
}
