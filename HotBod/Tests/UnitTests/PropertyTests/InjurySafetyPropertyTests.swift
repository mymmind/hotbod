import XCTest
@testable import HotBod

final class InjurySafetyPropertyTests: XCTestCase {
  func testGeneratedWorkoutsRespectRandomInjuryConstraints() async throws {
    let service = RulesWorkoutGenerationService()
    let catalog = try await LocalExerciseRepository().fetchAll()
    let exerciseMap = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
    var rng = SeededRandomNumberGenerator(seed: 301)

    for iteration in 0..<PropertyTestHelpers.iterationCount {
      let base = WorkoutGenerationInput.random(using: &rng)
      let injuryCount = Int.random(in: 0...3, using: &rng)
      let injuries = Array(BodyLimitation.allCases.shuffled(using: &rng).prefix(injuryCount))
      var profile = base.userProfile
      profile.limitations = injuries
      let input = base.with(profile: profile, injuries: injuries)

      do {
        let workout = try await service.generate(input: input)
        let validation = service.validate(workout: workout, input: input)
        XCTAssertTrue(validation.isValid, "Iteration \(iteration): \(validation.errors.joined(separator: "; "))")

        for planned in workout.exercises {
          guard let exercise = exerciseMap[planned.exerciseId] else { continue }
          XCTAssertFalse(
            GenerationConstants.violatesInjuries(exercise, injuries: injuries),
            "Iteration \(iteration): \(exercise.id) violates \(injuries)"
          )
        }
      } catch let failure as GenerationFailure {
        guard case .insufficientExercises = failure else {
          XCTFail("Iteration \(iteration): unexpected failure \(failure)")
          return
        }
      }
    }
  }
}
