import XCTest
@testable import HotBod

final class ProteinGoalCalculatorTests: XCTestCase {
    func testDefaultProteinGoal() {
        let goal = ProteinGoalCalculator.suggestedGoal(bodyWeightKg: 80, goal: .buildMuscle)
        XCTAssertEqual(goal, 144, accuracy: 1)
    }

    func testLoseFatHigherMultiplier() {
        let cut = ProteinGoalCalculator.suggestedGoal(bodyWeightKg: 80, goal: .loseFat)
        let build = ProteinGoalCalculator.suggestedGoal(bodyWeightKg: 80, goal: .buildMuscle)
        XCTAssertGreaterThan(cut, build)
    }
}

final class ProteinComplianceTests: XCTestCase {
    func testStreakCountsConsecutiveDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entries = (0..<3).flatMap { offset -> [ProteinEntry] in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            return [ProteinEntry(date: date, foodName: "Chicken", proteinGrams: 150)]
        }
        let summary = ProteinComplianceCalculator.summary(entries: entries, goalGrams: 145)
        XCTAssertGreaterThanOrEqual(summary.streakDays, 3)
    }
}
