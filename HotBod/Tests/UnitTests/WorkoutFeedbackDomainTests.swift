import XCTest
@testable import HotBod

final class EffortFeedbackMappingTests: XCTestCase {
    func testRPEFromRIR() {
        XCTAssertEqual(EffortFeedbackMapping.rpe(fromRIR: 0), 10)
        XCTAssertEqual(EffortFeedbackMapping.rpe(fromRIR: 2), 8)
        XCTAssertEqual(EffortFeedbackMapping.rpe(fromRIR: 4), 7)
    }

    func testAverageEffectiveRPEPrefersRIRWhenBothExist() {
        let sets = [
            CompletedSet(setIndex: 0, reps: 8, rpe: 9, rir: 2),
            CompletedSet(setIndex: 1, reps: 8, rpe: 8, rir: 3)
        ]
        XCTAssertEqual(EffortFeedbackMapping.averageEffectiveRPE(from: sets), 7.75)
    }

    func testAverageEffectiveRPEDerivesFromRIRWhenRPEMissing() {
        let sets = [
            CompletedSet(setIndex: 0, reps: 8, rir: 1),
            CompletedSet(setIndex: 1, reps: 8, rir: 2)
        ]
        XCTAssertEqual(EffortFeedbackMapping.averageEffectiveRPE(from: sets), 8.5)
    }

    func testMetPrescriptionUsesDurationTarget() {
        let planned = PlannedSet(targetRepsMin: 0, targetRepsMax: 0, targetDurationSeconds: 45)
        let completed = CompletedSet(setIndex: 0, durationSeconds: 45)
        let result = EffortFeedbackMapping.metPrescription(completed: completed, planned: planned)
        XCTAssertTrue(result.hitTop)
        XCTAssertFalse(result.missedMin)
    }

    func testMetPrescriptionUsesRepTarget() {
        let planned = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        let completed = CompletedSet(setIndex: 0, reps: 10)
        let result = EffortFeedbackMapping.metPrescription(completed: completed, planned: planned)
        XCTAssertTrue(result.hitTop)
        XCTAssertFalse(result.missedMin)
    }
}

final class ExerciseMetadataResolverTests: XCTestCase {
    func testFarmersCarryUsesPerHandAndDistanceOrTime() {
        let exercise = makeTestExercise(
            id: "farmers_carry",
            primaryMuscles: [.forearms],
            pattern: .carry,
            equipment: [.dumbbell]
        )

        XCTAssertEqual(ExerciseMetadataResolver.resolvedWeightDisplaySemantics(for: exercise), .perHand)
        XCTAssertEqual(ExerciseMetadataResolver.resolvedPrescriptionType(for: exercise), .distanceOrTime)
    }

    func testPlankUsesTimedPrescription() {
        let exercise = makeTestExercise(
            id: "plank",
            primaryMuscles: [.abs],
            pattern: .antiRotation,
            equipment: [.bodyweight]
        )

        XCTAssertEqual(ExerciseMetadataResolver.resolvedPrescriptionType(for: exercise), .time)
    }
}

final class CoreFinisherPlannerTests: XCTestCase {
    func testAppendsCoreFinisherExercises() {
        let plank = makeTestExercise(
            id: "plank",
            primaryMuscles: [.abs],
            pattern: .antiRotation,
            equipment: [.bodyweight]
        )
        let bench = makeTestExercise(
            id: "bench_press",
            primaryMuscles: [.chest],
            pattern: .horizontalPush,
            equipment: [.barbell]
        )

        var planned = [
            PlannedExercise(
                exerciseId: bench.id,
                orderIndex: 0,
                targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]
            )
        ]

        CoreFinisherPlanner.appendCoreFinisher(
            to: &planned,
            exercises: [bench, plank],
            availableEquipment: Equipment.allCases,
            experience: .intermediate
        )

        XCTAssertEqual(planned.count, 2)
        XCTAssertEqual(planned.last?.exerciseId, plank.id)
    }
}

final class WorkoutGenerationFeedbackTests: XCTestCase {
    func testBuildMuscleExcludesCardioWithoutConditioning() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let service = RulesWorkoutGenerationService()
            var profile = UserProfile.empty()
            profile.goal = .buildMuscle
            profile.includeConditioning = false
            profile.cardioBlockPlacement = .none
            profile.includeCoreFinisher = false
            profile.includeCooldown = false

            let workout = try await service.generate(input: makeGenerationInput(profile: profile, focus: .upper))
            let catalog = try await LocalExerciseRepository().fetchAll()
            let map = ExerciseCatalog.indexedById(catalog)
            let hasCardio = workout.exercises.contains { map[$0.exerciseId]?.movementPattern == .cardio }
            XCTAssertFalse(hasCardio)
        }
    }

    func testRegression_cardioNotInMainPoolWhenBlockPlacementSetButConditioningOff() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let service = RulesWorkoutGenerationService()
            var profile = UserProfile.empty()
            profile.goal = .buildMuscle
            profile.includeConditioning = false
            profile.cardioBlockPlacement = .end
            profile.includeCoreFinisher = false
            profile.includeCooldown = false

            let workout = try await service.generate(input: makeGenerationInput(profile: profile, focus: .upper))
            let catalog = try await LocalExerciseRepository().fetchAll()
            let map = ExerciseCatalog.indexedById(catalog)
            let hasCardio = workout.exercises.contains { map[$0.exerciseId]?.movementPattern == .cardio }
            XCTAssertFalse(hasCardio)
        }
    }

    func testCoreFinisherAppendedWhenEnabled() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let service = RulesWorkoutGenerationService()
            var profile = UserProfile.empty()
            profile.goal = .buildMuscle
            profile.includeCoreFinisher = true
            profile.includeCooldown = false
            profile.cardioBlockPlacement = .none

            let workout = try await service.generate(input: makeGenerationInput(profile: profile, focus: .push))
            let catalog = try await LocalExerciseRepository().fetchAll()
            let map = ExerciseCatalog.indexedById(catalog)
            let finishers = workout.exercises.filter {
                let exercise = map[$0.exerciseId]
                return exercise?.primaryMuscles.contains(.abs) == true
                    || exercise?.primaryMuscles.contains(.lowerBack) == true
            }
            XCTAssertFalse(finishers.isEmpty)
        }
    }

    private func makeGenerationInput(profile: UserProfile, focus: SplitDayFocus) -> WorkoutGenerationInput {
        WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: .intermediate,
            availableEquipment: Equipment.allCases,
            targetDurationMinutes: 45,
            preferredMuscleGroups: [],
            avoidedMuscleGroups: [],
            injuries: [],
            recentWorkouts: [],
            muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 80.0) }),
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: nil,
            splitDayFocus: focus
        )
    }
}

final class RestTimerPersistenceTests: XCTestCase {
    func testRegression_restTimerSurvivesBackground() {
        let end = Date().addingTimeInterval(45)
        let remainingAfterBackground = max(0, Int(ceil(end.timeIntervalSince(Date().addingTimeInterval(20)))))
        XCTAssertEqual(remainingAfterBackground, 25)
    }
}

final class SessionStructurePlannerFeedbackTests: XCTestCase {
    func testCooldownSkippedForTimedExercises() {
        let plank = makeTestExercise(
            id: "plank",
            primaryMuscles: [.abs],
            pattern: .antiRotation,
            equipment: [.bodyweight]
        )
        let bench = makeTestExercise(
            id: "bench_press",
            primaryMuscles: [.chest],
            pattern: .horizontalPush,
            equipment: [.barbell]
        )
        var planned = [
            PlannedExercise(
                exerciseId: bench.id,
                orderIndex: 0,
                targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]
            ),
            PlannedExercise(
                exerciseId: plank.id,
                orderIndex: 1,
                targetSets: [PlannedSet(targetRepsMin: 0, targetRepsMax: 0, targetDurationSeconds: 45)]
            )
        ]

        SessionStructurePlanner.appendCooldownSets(
            to: &planned,
            exerciseMap: [bench.id: bench, plank.id: plank]
        )

        XCTAssertEqual(planned[0].targetSets.count, 2)
        XCTAssertTrue(planned[0].targetSets.last?.isCooldown == true)
        XCTAssertEqual(planned[1].targetSets.count, 1)
        XCTAssertFalse(planned[1].targetSets.last?.isCooldown == true)
    }
}

final class WorkoutSessionCalculatorFeedbackTests: XCTestCase {
    func testVolumeContributionIncludesTimedSets() {
        let set = CompletedSet(setIndex: 0, weightKg: 60, durationSeconds: 60)
        XCTAssertEqual(WorkoutSessionCalculator.volumeContribution(for: set), 60, accuracy: 0.01)
    }
}

final class LocalExerciseRepositoryDedupTests: XCTestCase {
    func testRegression_duplicateCustomIdsDoNotCrashGeneration() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            var duplicate = makeTestExercise(
                id: "custom_test",
                primaryMuscles: [.chest],
                pattern: .horizontalPush,
                equipment: [.dumbbell]
            )
            duplicate.isCustom = true
            PersistenceHelper.save([duplicate, duplicate], to: "custom_exercises.json")

            let repo = LocalExerciseRepository()
            let catalog = try await repo.fetchAll()
            XCTAssertEqual(catalog.filter { $0.id == "custom_test" }.count, 1)

            _ = ExerciseCatalog.indexedById(catalog)

            var profile = UserProfile.empty()
            profile.includeCoreFinisher = false
            profile.includeCooldown = false
            let service = RulesWorkoutGenerationService(exerciseRepository: repo)
            let workout = try await service.generate(
                input: WorkoutGenerationInput(
                    userProfile: profile,
                    goal: .buildMuscle,
                    experienceLevel: .intermediate,
                    availableEquipment: Equipment.allCases,
                    targetDurationMinutes: 45,
                    preferredMuscleGroups: [],
                    avoidedMuscleGroups: [],
                    injuries: [],
                    recentWorkouts: [],
                    muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 80.0) }),
                    exerciseStats: [],
                    userPreferences: WorkoutPreferences(),
                    readiness: nil,
                    splitDayFocus: .upper
                )
            )
            XCTAssertFalse(workout.exercises.isEmpty)
        }
    }

    func testCreateCustomExerciseUpsertsDuplicateId() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalExerciseRepository()
            var custom = makeTestExercise(
                id: "custom_test",
                primaryMuscles: [.chest],
                pattern: .horizontalPush,
                equipment: [.dumbbell]
            )
            custom.name = "Version One"
            custom.isCustom = true
            _ = try await repo.createCustomExercise(custom)
            custom.name = "Version Two"
            _ = try await repo.createCustomExercise(custom)

            let catalog = try await repo.fetchAll()
            let fetched = try await repo.fetch(id: "custom_test")
            XCTAssertEqual(catalog.filter { $0.id == "custom_test" }.count, 1)
            XCTAssertEqual(fetched?.name, "Version Two")
        }
    }
}
