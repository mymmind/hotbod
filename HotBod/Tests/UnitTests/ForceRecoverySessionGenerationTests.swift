import XCTest
@testable import HotBod

extension FatigueAwareValidationTests {
    func testForceRecoverySessionIgnoresHighAverageRecovery() async throws {
        let service = RulesWorkoutGenerationService(exerciseRepository: LocalExerciseRepository())
        var profile = UserProfile.empty()
        profile.availableEquipment = Equipment.allCases
        // High average recovery, one critical muscle — would NOT auto-enter recovery mode.
        var recovery = Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 90.0) })
        recovery[.chest] = 10.0

        let input = WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment,
            targetDurationMinutes: 45,
            preferredMuscleGroups: [],
            avoidedMuscleGroups: [],
            injuries: [],
            recentWorkouts: [],
            muscleRecovery: recovery,
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: nil,
            splitDayFocus: .push,
            forceRecoverySession: true
        )

        let workout = try await service.generate(input: input)
        XCTAssertEqual(workout.sessionMode, .recovery)

        let validation = service.validate(workout: workout, input: input)
        XCTAssertTrue(validation.isValid, validation.errors.joined(separator: "; "))
    }
}
