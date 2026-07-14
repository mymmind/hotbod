import XCTest
@testable import HotBod

final class CoachSafetyPropertyTests: XCTestCase {
  func testSafeCoachModificationsStayWithinGuardrails() async throws {
    let catalog = try await LocalExerciseRepository().fetchAll()
    let allowedIds = catalog.map(\.id)
    var rng = SeededRandomNumberGenerator(seed: 811)

    for iteration in 0..<PropertyTestHelpers.iterationCount {
      let exerciseCount = Int.random(in: 4...6, using: &rng)
      let ids = Array(allowedIds.shuffled(using: &rng).prefix(exerciseCount))
      let currentDuration = Int.random(in: 40...60, using: &rng)
      let current = makeWorkout(duration: currentDuration, exerciseIds: ids, setsPerExercise: 3)

      let trimCount = Int.random(in: 0...min(2, ids.count - 4), using: &rng)
      let proposedIds = Array(ids.dropLast(trimCount))
      let proposedDuration = max(20, currentDuration - Int.random(in: 5...15, using: &rng))
      let proposed = makeWorkout(duration: proposedDuration, exerciseIds: proposedIds, setsPerExercise: 3)

      XCTAssertTrue(
        CoachModificationSafety.isSafeModification(
          proposed: proposed,
          current: current,
          allowedExerciseIds: Set(allowedIds)
        ),
        "Iteration \(iteration)"
      )
    }
  }

  private func makeWorkout(duration: Int, exerciseIds: [String], setsPerExercise: Int) -> GeneratedWorkout {
    GeneratedWorkout(
      id: UUID(),
      title: "Property Coach",
      estimatedDurationMinutes: duration,
      focus: [.chest],
      exercises: exerciseIds.enumerated().map { index, id in
        PlannedExercise(
          exerciseId: id,
          orderIndex: index,
          targetSets: (0..<setsPerExercise).map { _ in PlannedSet(targetRepsMin: 8, targetRepsMax: 10) }
        )
      },
      rationale: "",
      safetyNotes: [],
      generatedBy: .aiAssisted,
      createdAt: Date()
    )
  }
}
