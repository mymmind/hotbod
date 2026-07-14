import XCTest
@testable import HotBod

final class CatalogIntegrityPropertyTests: XCTestCase {
  func testCatalogSweepNeverLeavesUnknownWorkoutExerciseIds() async throws {
    let catalog = try await LocalExerciseRepository().fetchAll()
    let catalogIds = Set(catalog.map(\.id))
    var rng = SeededRandomNumberGenerator(seed: 1103)

    for iteration in 0..<PropertyTestHelpers.iterationCount {
      let exerciseCount = Int.random(in: 4...8, using: &rng)
      let selected = Array(catalog.shuffled(using: &rng).prefix(exerciseCount))
      let orphanCount = Int.random(in: 0...2, using: &rng)
      let orphanIds = (0..<orphanCount).map { _ in "orphan_\(Int.random(in: 0...999_999, using: &rng))" }
      let plannedIds = selected.map(\.id) + orphanIds

      var workout: GeneratedWorkout? = GeneratedWorkout(
        id: UUID(),
        title: "Sweep Test",
        estimatedDurationMinutes: 45,
        focus: selected.first?.primaryMuscles ?? [.chest],
        exercises: plannedIds.enumerated().map { index, id in
          PlannedExercise(
            exerciseId: id,
            orderIndex: index,
            targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]
          )
        },
        rationale: "",
        safetyNotes: [],
        generatedBy: .rulesEngine,
        createdAt: Date()
      )

      var stats = orphanIds.map {
        UserExerciseStats(
          exerciseId: $0,
          recentSets: [],
          preferredRepRangeMin: 8,
          preferredRepRangeMax: 12
        )
      }

      _ = CatalogIntegrity.sweep(catalogIds: catalogIds, workout: &workout, stats: &stats)

      if let workout {
        for planned in workout.exercises {
          XCTAssertTrue(catalogIds.contains(planned.exerciseId), "Iteration \(iteration)")
        }
      }

      for stat in stats where catalogIds.contains(stat.exerciseId) {
        XCTAssertFalse(stat.isOrphaned, "Iteration \(iteration)")
      }
      for stat in stats where !catalogIds.contains(stat.exerciseId) {
        XCTAssertTrue(stat.isOrphaned, "Iteration \(iteration)")
      }
    }
  }
}
