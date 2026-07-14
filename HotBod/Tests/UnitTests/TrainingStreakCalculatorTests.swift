import XCTest
@testable import HotBod

final class TrainingStreakCalculatorTests: XCTestCase {
    func testCountsConsecutiveCompletionDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let sessions = [
            completedSession(on: today),
            completedSession(on: yesterday),
            completedSession(on: twoDaysAgo)
        ]

        XCTAssertEqual(TrainingStreakCalculator.workoutStreak(sessions: sessions, asOf: today, calendar: calendar), 3)
    }

    func testAllowsIncompleteTodayIfYesterdayCompleted() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let sessions = [completedSession(on: yesterday)]
        XCTAssertEqual(TrainingStreakCalculator.workoutStreak(sessions: sessions, asOf: today, calendar: calendar), 1)
    }

    private func completedSession(on date: Date) -> WorkoutSession {
        WorkoutSession(
            userId: UUID(),
            title: "Test",
            startedAt: date,
            completedAt: date,
            estimatedDurationMinutes: 45,
            exercises: [],
            status: .completed
        )
    }
}
