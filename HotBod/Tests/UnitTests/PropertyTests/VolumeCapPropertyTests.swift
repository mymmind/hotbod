import XCTest
@testable import HotBod

final class VolumeCapPropertyTests: XCTestCase {
  func testGeneratedWorkoutsStayWithinWeeklyVolumeCap() async throws {
    let service = RulesWorkoutGenerationService()
    var rng = SeededRandomNumberGenerator(seed: 713)

    for iteration in 0..<PropertyTestHelpers.iterationCount {
      let input = WorkoutGenerationInput.random(using: &rng)
      let workout = try await service.generate(input: input)
      let validation = service.validate(workout: workout, input: input)
      let cap = WorkoutValidator.adjustedWeeklySetCap(for: input)

      XCTAssertTrue(validation.isValid, "Iteration \(iteration): \(validation.errors.joined(separator: "; "))")
      XCTAssertFalse(
        validation.errors.contains { $0.contains("Projected weekly volume") },
        "Iteration \(iteration) exceeded cap \(cap)"
      )
    }
  }
}
