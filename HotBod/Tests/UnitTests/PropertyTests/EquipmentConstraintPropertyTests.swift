import XCTest
@testable import HotBod

final class EquipmentConstraintPropertyTests: XCTestCase {
  func testGeneratedWorkoutsOnlyUseAvailableEquipment() async throws {
    let service = RulesWorkoutGenerationService()
    let catalog = try await LocalExerciseRepository().fetchAll()
    let exerciseMap = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
    var rng = SeededRandomNumberGenerator(seed: 417)

    for iteration in 0..<PropertyTestHelpers.iterationCount {
      let base = WorkoutGenerationInput.random(using: &rng)
      let equipmentCount = Int.random(in: 0...Equipment.allCases.count, using: &rng)
      let equipment = Array(Equipment.allCases.shuffled(using: &rng).prefix(equipmentCount))
      var profile = base.userProfile
      profile.availableEquipment = equipment
      let input = base.with(profile: profile, equipment: equipment)

      do {
        let workout = try await service.generate(input: input)
        for planned in workout.exercises {
          guard let exercise = exerciseMap[planned.exerciseId] else {
            XCTFail("Iteration \(iteration): unknown exercise \(planned.exerciseId)")
            continue
          }
          XCTAssertTrue(
            EquipmentFilter.isExerciseAvailable(exercise, availableEquipment: equipment),
            "Iteration \(iteration): \(exercise.id) unavailable for \(equipment)"
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
