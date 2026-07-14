import XCTest
@testable import HotBod

final class ProteinCompliancePropertyTests: XCTestCase {
  func testComplianceSummaryStaysConsistentWithRandomEntries() async throws {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    var rng = SeededRandomNumberGenerator(seed: 1009)

    for iteration in 0..<PropertyTestHelpers.iterationCount {
      let goal = Double.random(in: 100...200, using: &rng)
      let dayCount = Int.random(in: 1...14, using: &rng)
      var entries: [ProteinEntry] = []

      for offset in 0..<dayCount {
        guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
        let mealCount = Int.random(in: 1...4, using: &rng)
        for mealIndex in 0..<mealCount {
          let grams = Double.random(in: 10...60, using: &rng)
          entries.append(FixtureBuilders.makeProteinEntry(grams: grams, date: date, foodName: "Meal-\(mealIndex)"))
        }
      }

      let summary = ProteinComplianceCalculator.summary(entries: entries, goalGrams: goal)
      XCTAssertGreaterThanOrEqual(summary.streakDays, 0, "Iteration \(iteration)")
      XCTAssertLessThanOrEqual(summary.streakDays, dayCount, "Iteration \(iteration)")
      XCTAssertGreaterThanOrEqual(summary.todayGrams, 0, "Iteration \(iteration)")
      XCTAssertEqual(summary.goalGrams, goal, accuracy: 0.01, "Iteration \(iteration)")
    }
  }
}
