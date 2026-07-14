import XCTest
@testable import HotBod

final class ProgressiveOverloadPropertyTests: XCTestCase {
  func testProgressionNeverSuggestsNegativeWeight() async throws {
    let catalog = try await LocalExerciseRepository().fetchAll()
    var rng = SeededRandomNumberGenerator(seed: 611)

    for iteration in 0..<PropertyTestHelpers.iterationCount {
      let exercise = catalog[Int.random(in: 0..<catalog.count, using: &rng)]
      let currentWeight = Double.random(in: 20...140, using: &rng)
      let reps = Int.random(in: 4...12, using: &rng)
      let hitTop = Bool.random(using: &rng)
      let missedMin = hitTop ? false : Bool.random(using: &rng)

      let next = ProgressiveOverload.nextWeight(
        currentWeight: currentWeight,
        completedAllSetsAtTopRange: hitTop,
        missedMinimumReps: missedMin
      )
      XCTAssertGreaterThanOrEqual(next, 0, "Iteration \(iteration)")

      let sets = (0..<3).map {
        CompletedSet(
          setIndex: $0,
          weightKg: currentWeight,
          reps: reps,
          completedAt: Date()
        )
      }
      let planned = (0..<3).map { _ in PlannedSet(targetRepsMin: reps - 2, targetRepsMax: reps) }
      let stats = ProgressiveOverload.updateStats(
        existing: nil,
        exerciseId: exercise.id,
        completedSets: sets,
        plannedSets: planned,
        bodyweightKg: 80,
        experienceLevel: .intermediate,
        goal: .buildMuscle,
        equipment: exercise.equipment
      )

      if let suggested = stats.suggestedNextWeightKg {
        XCTAssertGreaterThanOrEqual(suggested, 0, "Iteration \(iteration)")
      }
    }
  }
}
