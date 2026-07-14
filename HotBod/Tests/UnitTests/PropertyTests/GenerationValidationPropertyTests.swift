import XCTest
@testable import HotBod

final class GenerationValidationPropertyTests: XCTestCase {
  func testGeneratedWorkoutsPassValidationAcrossRandomInputs() async throws {
    let service = RulesWorkoutGenerationService()
    let catalog = try await LocalExerciseRepository().fetchAll()
    var rng = SeededRandomNumberGenerator(seed: 2026)

    for iteration in 0..<PropertyTestHelpers.iterationCount {
      let input = WorkoutGenerationInput.random(using: &rng)
      let workout = try await service.generate(input: input)
      let validation = WorkoutValidator.validate(workout: workout, input: input, exercises: catalog)

      XCTAssertFalse(workout.exercises.isEmpty, "Iteration \(iteration)")
      XCTAssertTrue(
        validation.errors.isEmpty,
        "Iteration \(iteration): \(validation.errors.joined(separator: "; "))"
      )
    }
  }
}
