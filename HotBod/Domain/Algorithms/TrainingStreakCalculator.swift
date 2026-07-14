import Foundation

enum TrainingStreakCalculator {
    /// Consecutive calendar days with a completed workout, allowing today to be incomplete.
    static func workoutStreak(
        sessions: [WorkoutSession],
        asOf date: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let completionDays = Set(
            sessions.compactMap { session -> Date? in
                guard session.status == .completed, let completedAt = session.completedAt else { return nil }
                return calendar.startOfDay(for: completedAt)
            }
        )

        var checkDate = calendar.startOfDay(for: date)
        if !completionDays.contains(checkDate),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) {
            checkDate = yesterday
        }

        var streak = 0
        while completionDays.contains(checkDate) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previous
        }
        return streak
    }
}
