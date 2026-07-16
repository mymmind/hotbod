import XCTest
@testable import HotBod

final class WorkoutGenerationTests: XCTestCase {
    func testGenerateWorkoutReturnsExercises() async throws {
        let service = RulesWorkoutGenerationService()
        let profile = UserProfile.empty()
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
            muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 80.0) }),
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(soreness: .none),
            splitDayFocus: nil
        )
        let workout = try await service.generate(input: input)
        XCTAssertFalse(workout.exercises.isEmpty)
        XCTAssertFalse(workout.title.isEmpty)
    }

    func testWorkoutValidationRejectsUnknownExercise() {
        let workout = GeneratedWorkout(
            id: UUID(), title: "Test", estimatedDurationMinutes: 45,
            focus: [.chest], exercises: [
                PlannedExercise(exerciseId: "nonexistent_exercise", orderIndex: 0, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)])
            ],
            rationale: "", safetyNotes: [], generatedBy: .rulesEngine, createdAt: Date()
        )
        let profile = UserProfile.empty()
        let input = WorkoutGenerationInput(
            userProfile: profile, goal: profile.goal, experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment, targetDurationMinutes: 45,
            preferredMuscleGroups: [], avoidedMuscleGroups: [], injuries: [],
            recentWorkouts: [], muscleRecovery: [:], exerciseStats: [],
            userPreferences: WorkoutPreferences(), readiness: nil, splitDayFocus: nil
        )
        let result = WorkoutValidator.validate(workout: workout, input: input, exercises: [])
        XCTAssertFalse(result.isValid)
    }
}

final class EquipmentFilterTests: XCTestCase {
    func testBodyweightOnlyIncludedWithEmptyEquipment() {
        let exercise = makeTestExercise(
            id: "push_up",
            pattern: .horizontalPush,
            equipment: [.bodyweight]
        )
        XCTAssertTrue(EquipmentFilter.isExerciseAvailable(exercise, availableEquipment: []))
    }

    func testPartialEquipmentExcluded() {
        let exercise = makeTestExercise(
            id: "bench_press",
            pattern: .horizontalPush,
            equipment: [.barbell, .bench]
        )
        XCTAssertFalse(EquipmentFilter.isExerciseAvailable(exercise, availableEquipment: [.barbell]))
    }

    func testMatchingEquipmentIncluded() {
        let exercise = makeTestExercise(
            id: "curl",
            pattern: .isolation,
            equipment: [.dumbbell]
        )
        XCTAssertTrue(EquipmentFilter.isExerciseAvailable(exercise, availableEquipment: [.dumbbell]))
    }

    func testEmptyEquipmentArrayExcluded() {
        var exercise = makeTestExercise(id: "ghost", equipment: [.dumbbell])
        exercise.equipment = []
        XCTAssertFalse(EquipmentFilter.isExerciseAvailable(exercise, availableEquipment: [.dumbbell]))
    }
}

final class ResolvedMechanicsTests: XCTestCase {
    func testBenchPressDerivesCompoundRestAndFatigue() async throws {
        let exercises = try await LocalExerciseRepository().fetchAll()
        guard let bench = exercises.first(where: { $0.id == "bench_press" }) else {
            XCTFail("bench_press missing from seed")
            return
        }
        XCTAssertEqual(bench.resolvedMechanics, .compound)

        let pushCatalog = [
            bench,
            makeTestExercise(id: "incline_db_press", primaryMuscles: [.chest], pattern: .horizontalPush, equipment: [.dumbbell, .bench]),
            makeTestExercise(id: "cable_fly", primaryMuscles: [.chest], pattern: .isolation, equipment: [.cable]),
            makeTestExercise(id: "ohp", primaryMuscles: [.shoulders], pattern: .verticalPush, equipment: [.barbell])
        ]
        let service = RulesWorkoutGenerationService(exerciseRepository: TestRepositories.empty(exercises: pushCatalog).exercise)
        let profile = UserProfile.empty()
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
            muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 80.0) }),
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(soreness: .none),
            splitDayFocus: .push
        )
        let workout = try await service.generate(input: input)
        guard let planned = workout.exercises.first(where: { $0.exerciseId == "bench_press" }) else {
            XCTFail("Expected bench_press in generated workout")
            return
        }
        XCTAssertGreaterThanOrEqual(planned.restSeconds, GenerationConstants.Session.compoundRestSeconds)

        let compoundStates = RecoveryCalculator.applyWorkoutFatigue(
            states: RecoveryCalculator.defaultStates(),
            exercises: [bench],
            completedSets: [(bench, [CompletedSet(setIndex: 0, weightKg: 60, reps: 8)])]
        )
        let isolationExercise = Exercise(
            id: "iso_test", name: "Iso", slug: "iso", primaryMuscles: [.chest], secondaryMuscles: [],
            equipment: [.cable], movementPattern: .isolation, difficulty: .beginner,
            forceType: nil, mechanics: .isolation, instructions: [], formCues: [], commonMistakes: [],
            contraindications: [], substitutions: [], progressions: [], regressions: [],
            demoVideos: [], imageUrl: nil, tags: []
        )
        let isolationStates = RecoveryCalculator.applyWorkoutFatigue(
            states: RecoveryCalculator.defaultStates(),
            exercises: [isolationExercise],
            completedSets: [(isolationExercise, [CompletedSet(setIndex: 0, weightKg: 20, reps: 12)])]
        )
        let chestCompound = compoundStates.first { $0.muscleGroup == .chest }!.recoveryPercentage
        let chestIsolation = isolationStates.first { $0.muscleGroup == .chest }!.recoveryPercentage
        XCTAssertLessThan(chestCompound, chestIsolation)
    }
}

final class RecoverySessionGenerationTests: XCTestCase {
    private func makeInput(
        soreness: SorenessLevel = .none,
        recovery: [MuscleGroup: Double]? = nil
    ) -> WorkoutGenerationInput {
        let profile = UserProfile.empty()
        return WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment,
            targetDurationMinutes: 45,
            preferredMuscleGroups: [],
            avoidedMuscleGroups: [],
            injuries: [],
            recentWorkouts: [],
            muscleRecovery: recovery ?? Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 80.0) }),
            exerciseStats: [
                UserExerciseStats(
                    exerciseId: "bench_press",
                    lastWeightKg: 100,
                    lastReps: 8,
                    suggestedNextWeightKg: nil,
                    estimatedOneRepMax: nil,
                    bestVolumeSet: nil,
                    recentSets: [],
                    preferredRepRangeMin: 8,
                    preferredRepRangeMax: 10
                )
            ],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(soreness: soreness),
            splitDayFocus: .push
        )
    }

    func testSevereSorenessProducesRecoverySession() async throws {
        let service = RulesWorkoutGenerationService()
        let input = makeInput(soreness: .severe)
        let workout = try await service.generate(input: input)
        XCTAssertEqual(workout.sessionMode, .recovery)
        XCTAssertEqual(workout.title, "Recovery Session")
        XCTAssertGreaterThanOrEqual(workout.exercises.count, GenerationConstants.RecoverySession.minExercises)

        let validation = service.validate(workout: workout, input: input)
        XCTAssertTrue(validation.isValid, validation.errors.joined(separator: "; "))

        for planned in workout.exercises {
            for set in planned.targetSets {
                XCTAssertLessThanOrEqual(set.rpeTarget ?? 10, GenerationConstants.RecoverySession.rpeTarget)
                if let weight = set.targetWeightKg {
                    XCTAssertLessThanOrEqual(weight, 100 * GenerationConstants.RecoverySession.weightMultiplier + 0.01)
                }
            }
        }
    }

    func testLowAverageRecoveryProducesRecoverySession() async throws {
        let service = RulesWorkoutGenerationService()
        let lowRecovery = Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 20.0) })
        let input = makeInput(recovery: lowRecovery)
        let workout = try await service.generate(input: input)
        XCTAssertEqual(workout.sessionMode, .recovery)
        XCTAssertTrue(service.validate(workout: workout, input: input).isValid)
    }

    func testRecoveryModeStillRejectsDuplicateExercises() {
        let workout = GeneratedWorkout(
            id: UUID(),
            title: "Recovery Session",
            estimatedDurationMinutes: 30,
            focus: [.chest],
            exercises: [
                PlannedExercise(exerciseId: "bench_press", orderIndex: 0, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
                PlannedExercise(exerciseId: "bench_press", orderIndex: 1, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
                PlannedExercise(exerciseId: "push_up", orderIndex: 2, targetSets: [PlannedSet(targetRepsMin: 10, targetRepsMax: 12)])
            ],
            rationale: "",
            safetyNotes: [],
            generatedBy: .rulesEngine,
            createdAt: Date(),
            sessionMode: .recovery
        )
        let input = makeInput(soreness: .severe)
        let result = WorkoutValidator.validate(workout: workout, input: input, exercises: chestWorkoutExercises)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(where: { $0.contains("Duplicate") }))
    }
}

final class InjuryBlocklistTests: XCTestCase {
    private func exercise(pattern: MovementPattern, id: String = "test") -> Exercise {
        makeTestExercise(id: id, pattern: pattern)
    }

    func testElbowBlocksPressingPatterns() {
        XCTAssertTrue(GenerationConstants.violatesInjuries(exercise(pattern: .horizontalPush), injuries: [.elbow]))
        XCTAssertFalse(GenerationConstants.violatesInjuries(exercise(pattern: .horizontalPull), injuries: [.elbow]))
    }

    func testWristBlocksPressingPatterns() {
        XCTAssertTrue(GenerationConstants.violatesInjuries(exercise(pattern: .verticalPush), injuries: [.wrist]))
        XCTAssertFalse(GenerationConstants.violatesInjuries(exercise(pattern: .isolation), injuries: [.wrist]))
    }

    func testHipBlocksLowerBodyPatterns() {
        XCTAssertTrue(GenerationConstants.violatesInjuries(exercise(pattern: .hinge), injuries: [.hip]))
        XCTAssertTrue(GenerationConstants.violatesInjuries(exercise(pattern: .lunge), injuries: [.hip]))
        XCTAssertFalse(GenerationConstants.violatesInjuries(exercise(pattern: .horizontalPull), injuries: [.hip]))
    }

    func testAnkleBlocksSquatAndLunge() {
        XCTAssertTrue(GenerationConstants.violatesInjuries(exercise(pattern: .squat), injuries: [.ankle]))
        XCTAssertTrue(GenerationConstants.violatesInjuries(exercise(pattern: .lunge), injuries: [.ankle]))
        XCTAssertFalse(GenerationConstants.violatesInjuries(exercise(pattern: .horizontalPush), injuries: [.ankle]))
    }

    func testNeckBlocksVerticalPush() {
        XCTAssertTrue(GenerationConstants.violatesInjuries(exercise(pattern: .verticalPush), injuries: [.neck]))
        XCTAssertFalse(GenerationConstants.violatesInjuries(exercise(pattern: .horizontalPush), injuries: [.neck]))
    }

    func testContraindicationTextBlocksExerciseForMatchingLimitation() {
        var exercise = makeTestExercise(id: "knee_sensitive_row", pattern: .horizontalPull)
        exercise.contraindications = ["Not recommended with knee pain flare-ups."]
        XCTAssertTrue(GenerationConstants.violatesInjuries(exercise, injuries: [.knee]))
    }

    func testContraindicationTextDoesNotBlockDifferentLimitation() {
        var exercise = makeTestExercise(id: "shoulder_sensitive_press", pattern: .horizontalPush)
        exercise.contraindications = ["Avoid if shoulder impingement is active."]
        XCTAssertFalse(GenerationConstants.violatesInjuries(exercise, injuries: [.ankle]))
    }

    func testGeneratedWorkoutRespectsHipLimitation() async throws {
        let service = RulesWorkoutGenerationService()
        var profile = UserProfile.empty()
        profile.limitations = [.hip]
        let input = WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment,
            targetDurationMinutes: 45,
            preferredMuscleGroups: [],
            avoidedMuscleGroups: [],
            injuries: [.hip],
            recentWorkouts: [],
            muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 80.0) }),
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(soreness: .none),
            splitDayFocus: .legs
        )
        let workout = try await service.generate(input: input)
        let exercises = try await LocalExerciseRepository().fetchAll()
        let exerciseMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        let validation = service.validate(workout: workout, input: input)
        XCTAssertTrue(validation.isValid, validation.errors.joined(separator: "; "))
        for planned in workout.exercises {
            guard let exercise = exerciseMap[planned.exerciseId] else { continue }
            XCTAssertFalse(
                GenerationConstants.violatesInjuries(exercise, injuries: [.hip]),
                "\(exercise.id) should be excluded for hip limitation"
            )
        }
    }
}

final class SleepScoreGenerationTests: XCTestCase {
    func testPoorSleepRecoveryPenaltyAppliedToSortKey() {
        let profile = UserProfile.empty()
        let recovery: [MuscleGroup: Double] = [.back: 60, .shoulders: 60]
        let input = WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment,
            targetDurationMinutes: 45,
            preferredMuscleGroups: [.back],
            avoidedMuscleGroups: [],
            injuries: [],
            recentWorkouts: [],
            muscleRecovery: recovery,
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(sleepScore: 40, soreness: .none),
            splitDayFocus: .upper
        )
        XCTAssertEqual(recoverySortKeyForTests(.back, input: input, preferred: [.back]), 65)
        XCTAssertEqual(recoverySortKeyForTests(.shoulders, input: input, preferred: []), 50)
    }

    func testNilSleepScoreLeavesRecoveryUnchanged() {
        let profile = UserProfile.empty()
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
            muscleRecovery: [.back: 60],
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(sleepScore: nil, soreness: .none),
            splitDayFocus: .upper
        )
        XCTAssertEqual(recoverySortKeyForTests(.back, input: input, preferred: []), 60)
    }

    func testPoorSleepCapsRpeAndReducesCompoundSets() async throws {
        let service = RulesWorkoutGenerationService()
        var profile = UserProfile.empty()
        profile.experienceLevel = .intermediate
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
            muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 80.0) }),
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(sleepScore: 40, soreness: .none),
            splitDayFocus: .push
        )
        let workout = try await service.generate(input: input)
        let exercises = try await LocalExerciseRepository().fetchAll()
        let exerciseMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })

        let compoundSets = workout.exercises.compactMap { planned -> Int? in
            guard let exercise = exerciseMap[planned.exerciseId],
                  exercise.resolvedMechanics == .compound else { return nil }
            return planned.targetSets.filter { !$0.isWarmup }.count
        }
        if let firstCompoundCount = compoundSets.first {
            XCTAssertLessThanOrEqual(firstCompoundCount, 3)
        }

        for planned in workout.exercises {
            for set in planned.targetSets {
                XCTAssertLessThanOrEqual(set.rpeTarget ?? 10, GenerationConstants.Session.poorSleepMaxRpe)
            }
        }
    }
}

final class MusclePreferenceGenerationTests: XCTestCase {
    func testAvoidedChestExcludedOnPushDay() async throws {
        let service = RulesWorkoutGenerationService()
        let profile = UserProfile.empty()
        let input = WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment,
            targetDurationMinutes: 45,
            preferredMuscleGroups: [],
            avoidedMuscleGroups: [.chest],
            injuries: [],
            recentWorkouts: [],
            muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 80.0) }),
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(soreness: .none),
            splitDayFocus: .push
        )
        let workout = try await service.generate(input: input)
        let exercises = try await LocalExerciseRepository().fetchAll()
        let exerciseMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })

        XCTAssertFalse(workout.focus.contains(.chest))
        for planned in workout.exercises {
            let exercise = exerciseMap[planned.exerciseId]
            XCTAssertFalse(exercise?.primaryMuscles.contains(.chest) ?? false)
        }
    }

    func testPreferredBackWinsOnUpperDay() async throws {
        let service = RulesWorkoutGenerationService()
        let profile = UserProfile.empty()
        let equalRecovery = Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 70.0) })
        let input = WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment,
            targetDurationMinutes: 45,
            preferredMuscleGroups: [.back],
            avoidedMuscleGroups: [],
            injuries: [],
            recentWorkouts: [],
            muscleRecovery: equalRecovery,
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(soreness: .none),
            splitDayFocus: .upper
        )
        let workout = try await service.generate(input: input)
        XCTAssertTrue(workout.focus.contains(.back))
        let exercises = try await LocalExerciseRepository().fetchAll()
        let exerciseMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        XCTAssertTrue(
            workout.exercises.contains {
                exerciseMap[$0.exerciseId]?.primaryMuscles.contains(.back) == true
            }
        )
    }

    func testAvoidedMuscleOverrideAddsWarning() async throws {
        let service = RulesWorkoutGenerationService()
        let profile = UserProfile.empty()
        let input = WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment,
            targetDurationMinutes: 45,
            preferredMuscleGroups: [],
            avoidedMuscleGroups: [.chest, .shoulders, .triceps],
            injuries: [],
            recentWorkouts: [],
            muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 80.0) }),
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(soreness: .none),
            splitDayFocus: .push
        )
        let workout = try await service.generate(input: input)
        XCTAssertTrue(
            workout.safetyNotes.contains(GenerationConstants.Targeting.avoidedMusclesOverrideMessage)
        )
    }
}

final class FavoriteExerciseScoringTests: XCTestCase {
    func testFavoriteWinsTieBreak() {
        let a = makeTestExercise(id: "exercise_a", primaryMuscles: [.chest])
        let b = makeTestExercise(id: "exercise_b", primaryMuscles: [.chest])
        let target: [MuscleGroup] = [.chest]

        func score(favorites: Set<String>, exercise: Exercise) -> Double {
            let muscleScore = Double(exercise.primaryMuscles.filter { target.contains($0) }.count)
                * GenerationConstants.Scoring.primaryMuscleWeight
            let favoriteBonus = favorites.contains(exercise.id) ? GenerationConstants.Scoring.favoriteBonus : 0
            return muscleScore + favoriteBonus
        }

        let favorites: Set<String> = ["exercise_b"]
        XCTAssertGreaterThan(score(favorites: favorites, exercise: b), score(favorites: favorites, exercise: a))
    }
}

final class SuggestedStartWeightGenerationTests: XCTestCase {
    func testHingeStartWeightExceedsVerticalPushForBeginner() {
        let bodyweight = 80.0
        let hinge = makeTestExercise(id: "deadlift", primaryMuscles: [.hamstrings], pattern: .hinge, equipment: [.barbell])
        let press = makeTestExercise(id: "ohp", primaryMuscles: [.shoulders], pattern: .verticalPush, equipment: [.barbell])
        let hingeWeight = ProgressiveOverload.suggestedStartWeight(for: hinge, bodyweight: bodyweight, experience: .beginner)
        let pressWeight = ProgressiveOverload.suggestedStartWeight(for: press, bodyweight: bodyweight, experience: .beginner)
        XCTAssertGreaterThan(hingeWeight, pressWeight)
    }

    func testZeroBodyweightFallsBackToFlatDefault() async throws {
        let bench = makeTestExercise(
            id: "bench_press",
            primaryMuscles: [.chest],
            pattern: .horizontalPush,
            equipment: [.barbell, .bench]
        )
        let support = [
            makeTestExercise(id: "incline_barbell_press", primaryMuscles: [.chest], pattern: .horizontalPush, equipment: [.barbell, .bench]),
            makeTestExercise(id: "close_grip_bench", primaryMuscles: [.chest, .triceps], pattern: .horizontalPush, equipment: [.barbell, .bench]),
            makeTestExercise(id: "ohp", primaryMuscles: [.shoulders], pattern: .verticalPush, equipment: [.barbell])
        ]
        let repos = TestRepositories.empty(exercises: [bench] + support)
        let service = RulesWorkoutGenerationService(exerciseRepository: repos.exercise)
        var profile = UserProfile.empty()
        profile.weightKg = 0
        profile.experienceLevel = .beginner
        let input = WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: .beginner,
            availableEquipment: [.barbell, .bench],
            targetDurationMinutes: 45,
            preferredMuscleGroups: [],
            avoidedMuscleGroups: [],
            injuries: [],
            recentWorkouts: [],
            muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 80.0) }),
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(soreness: .none),
            splitDayFocus: .push
        )
        let workout = try await service.generate(input: input)
        guard let bench = workout.exercises.first(where: { $0.exerciseId == "bench_press" }) else {
            XCTFail("Expected bench_press")
            return
        }
        let workingWeight = bench.targetSets.first { !$0.isWarmup }?.targetWeightKg ?? 0
        XCTAssertEqual(workingWeight, 40, accuracy: 0.01)
    }

    func testBeginnerClampLimitsAggressiveSuggestion() {
        let squat = makeTestExercise(id: "squat", primaryMuscles: [.quads], pattern: .squat, equipment: [.barbell])
        let flat: Double = 40
        let suggested = ProgressiveOverload.suggestedStartWeight(for: squat, bodyweight: 120, experience: .beginner)
        XCTAssertGreaterThan(suggested, flat * GenerationConstants.Session.beginnerStartWeightClampMultiplier)
    }

    func testBeginnerHeavySquatClampedInGeneratedWorkout() async throws {
        let squat = makeTestExercise(id: "squat", primaryMuscles: [.quads], pattern: .squat, equipment: [.barbell, .squatRack])
        let support = [
            makeTestExercise(id: "rdl", primaryMuscles: [.hamstrings], pattern: .hinge, equipment: [.barbell]),
            makeTestExercise(id: "leg_press", primaryMuscles: [.quads], pattern: .squat, equipment: [.machine]),
            makeTestExercise(id: "leg_curl", primaryMuscles: [.hamstrings], pattern: .isolation, equipment: [.machine])
        ]
        let repos = TestRepositories.empty(exercises: [squat] + support)
        let service = RulesWorkoutGenerationService(exerciseRepository: repos.exercise)
        var profile = UserProfile.empty()
        profile.weightKg = 120
        profile.experienceLevel = .beginner
        let input = WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: .beginner,
            availableEquipment: Equipment.allCases,
            targetDurationMinutes: 45,
            preferredMuscleGroups: [],
            avoidedMuscleGroups: [],
            injuries: [],
            recentWorkouts: [],
            muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 80.0) }),
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(soreness: .none),
            splitDayFocus: .legs
        )
        let workout = try await service.generate(input: input)
        guard let squat = workout.exercises.first(where: { $0.exerciseId == "squat" }) else {
            XCTFail("Expected squat in legs workout")
            return
        }
        let workingWeight = squat.targetSets.first { !$0.isWarmup }?.targetWeightKg ?? 0
        XCTAssertEqual(workingWeight, 40, accuracy: 0.01)
    }
}

final class FatigueAwareValidationTests: XCTestCase {
    func testCriticalFatigueRejectsWorkout() {
        let workout = GeneratedWorkout(
            id: UUID(), title: "Test", estimatedDurationMinutes: 45,
            focus: [.chest], exercises: [
                PlannedExercise(exerciseId: "bench_press", orderIndex: 0, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
                PlannedExercise(exerciseId: "incline_press", orderIndex: 1, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
                PlannedExercise(exerciseId: "dumbbell_press", orderIndex: 2, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
                PlannedExercise(exerciseId: "cable_fly", orderIndex: 3, targetSets: [PlannedSet(targetRepsMin: 10, targetRepsMax: 12)])
            ],
            rationale: "", safetyNotes: [], generatedBy: .rulesEngine, createdAt: Date()
        )
        
        let profile = UserProfile.empty()
        let criticalRecovery = [
            MuscleGroup.chest: 10.0,  // < 15%: critical
            MuscleGroup.shoulders: 25.0,
            MuscleGroup.triceps: 50.0
        ]
        let input = WorkoutGenerationInput(
            userProfile: profile, goal: profile.goal, experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment, targetDurationMinutes: 45,
            preferredMuscleGroups: [], avoidedMuscleGroups: [], injuries: [],
            recentWorkouts: [], muscleRecovery: criticalRecovery, exerciseStats: [],
            userPreferences: WorkoutPreferences(), readiness: nil, splitDayFocus: nil
        )
        
        let result = WorkoutValidator.validate(workout: workout, input: input, exercises: chestWorkoutExercises)
        XCTAssertFalse(result.isValid, "Should reject workout with critical fatigue")
        XCTAssertTrue(result.errors.contains(where: { $0.contains("Critical fatigue") }))
    }

    func testLowFatigueWarning() {
        let workout = GeneratedWorkout(
            id: UUID(), title: "Test", estimatedDurationMinutes: 45,
            focus: [.chest], exercises: [
                PlannedExercise(exerciseId: "bench_press", orderIndex: 0, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
                PlannedExercise(exerciseId: "incline_press", orderIndex: 1, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
                PlannedExercise(exerciseId: "dumbbell_press", orderIndex: 2, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
                PlannedExercise(exerciseId: "cable_fly", orderIndex: 3, targetSets: [PlannedSet(targetRepsMin: 10, targetRepsMax: 12)])
            ],
            rationale: "", safetyNotes: [], generatedBy: .rulesEngine, createdAt: Date()
        )
        
        let profile = UserProfile.empty()
        let lowRecovery = [
            MuscleGroup.chest: 25.0,  // 15-30%: warning
            MuscleGroup.shoulders: 50.0,
            MuscleGroup.triceps: 60.0
        ]
        let input = WorkoutGenerationInput(
            userProfile: profile, goal: profile.goal, experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment, targetDurationMinutes: 45,
            preferredMuscleGroups: [], avoidedMuscleGroups: [], injuries: [],
            recentWorkouts: [], muscleRecovery: lowRecovery, exerciseStats: [],
            userPreferences: WorkoutPreferences(), readiness: nil, splitDayFocus: nil
        )
        
        let result = WorkoutValidator.validate(workout: workout, input: input, exercises: chestWorkoutExercises)
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.warnings.contains(where: { $0.contains("Low fatigue") }))
    }

    func testHighVolumeSoftCap() {
        let catalog = (0..<8).map { i in
            let muscle: MuscleGroup = i % 2 == 0 ? .chest : .back
            return makeTestExercise(id: "exercise_\(i)", primaryMuscles: [muscle])
        }
        let manyExercises = catalog.enumerated().map { index, exercise in
            PlannedExercise(
                exerciseId: exercise.id, orderIndex: index,
                targetSets: (0..<20).map { _ in PlannedSet(targetRepsMin: 8, targetRepsMax: 10) }
            )
        }
        
        let workout = GeneratedWorkout(
            id: UUID(), title: "Test", estimatedDurationMinutes: 120,
            focus: [.chest, .back], exercises: manyExercises,
            rationale: "", safetyNotes: [], generatedBy: .rulesEngine, createdAt: Date()
        )
        
        let profile = UserProfile.empty()
        let input = WorkoutGenerationInput(
            userProfile: profile, goal: profile.goal, experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment, targetDurationMinutes: 120,
            preferredMuscleGroups: [], avoidedMuscleGroups: [], injuries: [],
            recentWorkouts: [], muscleRecovery: [:], exerciseStats: [],
            userPreferences: WorkoutPreferences(), readiness: nil, splitDayFocus: nil
        )
        
        let result = WorkoutValidator.validate(workout: workout, input: input, exercises: catalog)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(where: { $0.contains("Projected weekly volume") }))
    }

    func testSeveresorenessReducesVolume() {
        let workout = GeneratedWorkout(
            id: UUID(), title: "Test", estimatedDurationMinutes: 45,
            focus: [.chest], exercises: [
                PlannedExercise(exerciseId: "bench_press", orderIndex: 0, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
                PlannedExercise(exerciseId: "incline_press", orderIndex: 1, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
                PlannedExercise(exerciseId: "dumbbell_press", orderIndex: 2, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
                PlannedExercise(exerciseId: "cable_fly", orderIndex: 3, targetSets: [PlannedSet(targetRepsMin: 10, targetRepsMax: 12)])
            ],
            rationale: "", safetyNotes: [], generatedBy: .rulesEngine, createdAt: Date()
        )
        
        let profile = UserProfile.empty()
        let input = WorkoutGenerationInput(
            userProfile: profile, goal: profile.goal, experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment, targetDurationMinutes: 45,
            preferredMuscleGroups: [], avoidedMuscleGroups: [], injuries: [],
            recentWorkouts: [], muscleRecovery: [:], exerciseStats: [],
            userPreferences: WorkoutPreferences(), readiness: ReadinessInput(soreness: .severe), splitDayFocus: nil
        )
        
        let result = WorkoutValidator.validate(workout: workout, input: input, exercises: chestWorkoutExercises)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(where: { $0.contains("Severe soreness") }))
        XCTAssertTrue(result.suggestions.contains(where: { $0.localizedCaseInsensitiveContains("swap") }))
    }

    func testHighIntensityLowRecoveryWarning() {
        // Create high-intensity workout: low reps, many sets, compounds
        let exercises = [
            PlannedExercise(exerciseId: "bench_press", orderIndex: 0, targetSets: [
                PlannedSet(targetRepsMin: 3, targetRepsMax: 5),
                PlannedSet(targetRepsMin: 3, targetRepsMax: 5),
                PlannedSet(targetRepsMin: 3, targetRepsMax: 5),
                PlannedSet(targetRepsMin: 3, targetRepsMax: 5)
            ]),
            PlannedExercise(exerciseId: "squat", orderIndex: 1, targetSets: [
                PlannedSet(targetRepsMin: 3, targetRepsMax: 5),
                PlannedSet(targetRepsMin: 3, targetRepsMax: 5),
                PlannedSet(targetRepsMin: 3, targetRepsMax: 5),
                PlannedSet(targetRepsMin: 3, targetRepsMax: 5)
            ]),
            PlannedExercise(exerciseId: "deadlift", orderIndex: 2, targetSets: [
                PlannedSet(targetRepsMin: 3, targetRepsMax: 5),
                PlannedSet(targetRepsMin: 3, targetRepsMax: 5),
                PlannedSet(targetRepsMin: 3, targetRepsMax: 5),
                PlannedSet(targetRepsMin: 3, targetRepsMax: 5)
            ]),
            PlannedExercise(exerciseId: "pull_up", orderIndex: 3, targetSets: [
                PlannedSet(targetRepsMin: 3, targetRepsMax: 5),
                PlannedSet(targetRepsMin: 3, targetRepsMax: 5),
                PlannedSet(targetRepsMin: 3, targetRepsMax: 5),
                PlannedSet(targetRepsMin: 3, targetRepsMax: 5)
            ])
        ]
        
        let workout = GeneratedWorkout(
            id: UUID(), title: "Power Day", estimatedDurationMinutes: 60,
            focus: [.chest, .quads, .back], exercises: exercises,
            rationale: "", safetyNotes: [], generatedBy: .rulesEngine, createdAt: Date()
        )
        
        let profile = UserProfile.empty()
        let lowRecovery = [
            MuscleGroup.chest: 40.0,
            MuscleGroup.quads: 35.0,
            MuscleGroup.back: 45.0,
            MuscleGroup.glutes: 50.0
        ]
        let input = WorkoutGenerationInput(
            userProfile: profile, goal: profile.goal, experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment, targetDurationMinutes: 60,
            preferredMuscleGroups: [], avoidedMuscleGroups: [], injuries: [],
            recentWorkouts: [], muscleRecovery: lowRecovery, exerciseStats: [],
            userPreferences: WorkoutPreferences(), readiness: nil, splitDayFocus: nil
        )
        
        let catalog: [Exercise] = [
            makeTestExercise(id: "bench_press", primaryMuscles: [.chest]),
            makeTestExercise(id: "squat", primaryMuscles: [.quads], pattern: .squat),
            makeTestExercise(id: "deadlift", primaryMuscles: [.hamstrings, .glutes], pattern: .hinge),
            makeTestExercise(id: "pull_up", primaryMuscles: [.back], pattern: .verticalPull)
        ]
        let result = WorkoutValidator.validate(workout: workout, input: input, exercises: catalog)
        XCTAssertTrue(result.warnings.contains(where: { $0.contains("High intensity") }))
    }

    func testCriticalFatigueOnlyErrorsAllowRecoveryOverride() {
        let errors = [
            "Critical fatigue detected (10% recovery). Recommend lighter session or rest day.",
            "Chest critically fatigued (<15% recovery). Bench Press not recommended."
        ]
        XCTAssertTrue(GenerationFailure.allowsRecoveryOverride(errors: errors))
    }

    func testMixedValidationErrorsDoNotAllowRecoveryOverride() {
        let errors = [
            "Critical fatigue detected (10% recovery). Recommend lighter session or rest day.",
            "Projected weekly volume (120 sets) exceeds safe threshold (100). Consider deload."
        ]
        XCTAssertFalse(GenerationFailure.allowsRecoveryOverride(errors: errors))
    }

    func testEmptyErrorsDoNotAllowRecoveryOverride() {
        XCTAssertFalse(GenerationFailure.allowsRecoveryOverride(errors: []))
    }
}

final class WorkoutGenerationAlgorithmsTests: XCTestCase {
    func testOrderForSessionCompoundBeforeIsolation() {
        let squat = makeTestExercise(id: "squat", primaryMuscles: [.quads], pattern: .squat, mechanics: .compound)
        let curl = makeTestExercise(id: "curl", primaryMuscles: [.biceps], pattern: .isolation, mechanics: .isolation)
        let ordered = WorkoutGenerationAlgorithms.orderForSession([
            (curl, 20),
            (squat, 10)
        ])
        XCTAssertEqual(ordered.first?.id, "squat")
    }

    func testSelectExercisesCoversEachTargetMuscle() {
        let targets: [MuscleGroup] = [.chest, .back, .quads, .shoulders]
        let exercises = [
            makeTestExercise(id: "bench", primaryMuscles: [.chest]),
            makeTestExercise(id: "row", primaryMuscles: [.back], pattern: .horizontalPull),
            makeTestExercise(id: "squat", primaryMuscles: [.quads], pattern: .squat),
            makeTestExercise(id: "ohp", primaryMuscles: [.shoulders], pattern: .verticalPush),
            makeTestExercise(id: "curl", primaryMuscles: [.biceps], pattern: .isolation, mechanics: .isolation)
        ]
        let scored = WorkoutGenerationAlgorithms.scoreExercises(
            exercises,
            targetMuscles: targets,
            experience: .intermediate,
            stats: [],
            recoveryBias: false
        )
        let ranked = WorkoutGenerationAlgorithms.rankScored(scored, variability: .consistent, avoidIds: [])
        let result = WorkoutGenerationAlgorithms.selectExercises(
            ranked: ranked,
            targetMuscles: targets,
            maxExercises: 4,
            minExercises: 4
        )
        XCTAssertEqual(result.exercises.count, 4)
        for muscle in targets {
            XCTAssertTrue(
                result.exercises.contains { $0.primaryMuscles.contains(muscle) },
                "Missing coverage for \(muscle)"
            )
        }
    }

    func testSecondaryMuscleScoringBonus() {
        let primaryOnly = makeTestExercise(id: "primary_only", primaryMuscles: [.chest])
        let withSecondary = makeTestExercise(
            id: "secondary_match",
            primaryMuscles: [.triceps],
            secondaryMuscles: [.chest],
            pattern: .isolation,
            mechanics: .isolation
        )
        let targets: [MuscleGroup] = [.chest]
        let scored = WorkoutGenerationAlgorithms.scoreExercises(
            [primaryOnly, withSecondary],
            targetMuscles: targets,
            experience: .intermediate,
            stats: [],
            recoveryBias: false
        )
        let primaryScore = scored.first { $0.0.id == "primary_only" }?.1 ?? 0
        let secondaryScore = scored.first { $0.0.id == "secondary_match" }?.1 ?? 0
        XCTAssertGreaterThan(primaryScore, secondaryScore)
        XCTAssertEqual(secondaryScore, GenerationConstants.Scoring.secondaryMuscleWeight)
    }

    func testLessPreferredExerciseScoresLowerThanNeutralPeer() {
        let neutral = makeTestExercise(id: "neutral_press", primaryMuscles: [.chest])
        var less = makeTestExercise(id: "less_press", primaryMuscles: [.chest])
        less.preference = .less
        let scored = WorkoutGenerationAlgorithms.scoreExercises(
            [neutral, less],
            targetMuscles: [.chest],
            experience: .intermediate,
            stats: [],
            recoveryBias: false
        )
        let neutralScore = scored.first { $0.0.id == "neutral_press" }?.1 ?? 0
        let lessScore = scored.first { $0.0.id == "less_press" }?.1 ?? 0
        XCTAssertEqual(
            lessScore,
            neutralScore + GenerationConstants.Scoring.lessPreferredPenalty,
            accuracy: 0.001
        )
    }

    func testStrengthGoalUsesLongCompoundRest() {
        let rest = WorkoutGenerationAlgorithms.restSeconds(goal: .gainStrength, mechanics: .compound)
        XCTAssertEqual(rest, GenerationConstants.Session.strengthCompoundRestSeconds)
    }

    func testDeloadAndBeginnerRpeTargets() {
        XCTAssertEqual(
            WorkoutGenerationAlgorithms.rpeTarget(
                sessionMode: .standard,
                experience: .intermediate,
                isDeload: true,
                sleepScore: nil
            ),
            GenerationConstants.Session.deloadRpeTarget
        )
        XCTAssertEqual(
            WorkoutGenerationAlgorithms.rpeTarget(
                sessionMode: .standard,
                experience: .beginner,
                isDeload: false,
                sleepScore: nil
            ),
            GenerationConstants.Session.beginnerRpeTarget
        )
    }

    func testTrimToDurationRespectsOverTargetFraction() {
        let targets: [MuscleGroup] = [.chest, .back, .quads, .shoulders]
        let exerciseMap: [String: Exercise] = [
            "bench": makeTestExercise(id: "bench", primaryMuscles: [.chest]),
            "row": makeTestExercise(id: "row", primaryMuscles: [.back], pattern: .horizontalPull),
            "squat": makeTestExercise(id: "squat", primaryMuscles: [.quads], pattern: .squat),
            "ohp": makeTestExercise(id: "ohp", primaryMuscles: [.shoulders], pattern: .verticalPush),
            "curl": makeTestExercise(id: "curl", primaryMuscles: [.biceps], pattern: .isolation, mechanics: .isolation),
            "fly": makeTestExercise(id: "fly", primaryMuscles: [.chest], pattern: .isolation, mechanics: .isolation)
        ]
        var planned: [PlannedExercise] = [
            makePlannedExercise(id: "bench", sets: 3, rest: 180),
            makePlannedExercise(id: "row", sets: 3, rest: 180),
            makePlannedExercise(id: "squat", sets: 3, rest: 180),
            makePlannedExercise(id: "ohp", sets: 3, rest: 180),
            makePlannedExercise(id: "curl", sets: 3, rest: 90),
            makePlannedExercise(id: "fly", sets: 3, rest: 90)
        ]
        var scores = Dictionary(uniqueKeysWithValues: planned.map { ($0.exerciseId, 10.0) })
        scores["curl"] = 5
        scores["fly"] = 4
        let targetDuration = 45
        let before = WorkoutGenerationAlgorithms.estimateDurationMinutes(planned: planned)
        WorkoutGenerationAlgorithms.trimToDuration(
            planned: &planned,
            scores: scores,
            targetMuscles: targets,
            exerciseMap: exerciseMap,
            targetDurationMinutes: targetDuration
        )
        let maxDuration = Int(Double(targetDuration) * GenerationConstants.Session.durationOverTargetFraction)
        XCTAssertGreaterThan(before, maxDuration)
        XCTAssertLessThanOrEqual(WorkoutGenerationAlgorithms.estimateDurationMinutes(planned: planned), maxDuration)
        XCTAssertGreaterThanOrEqual(planned.count, GenerationConstants.Session.minStandardExercises)
    }

    func testJitterDeterministicAndPreservesLargeGaps() {
        let low = makeTestExercise(id: "low", primaryMuscles: [.chest])
        let high = makeTestExercise(id: "high", primaryMuscles: [.chest])
        let scored: [(Exercise, Double)] = [(low, 10), (high, 20)]
        let ranked1 = WorkoutGenerationAlgorithms.rankScored(
            scored,
            variability: .varied,
            avoidIds: ["unused"],
            variationSeed: 42
        )
        let ranked2 = WorkoutGenerationAlgorithms.rankScored(
            scored,
            variability: .varied,
            avoidIds: ["unused"],
            variationSeed: 42
        )
        XCTAssertEqual(ranked1.map(\.0.id), ranked2.map(\.0.id))
        XCTAssertEqual(ranked1.first?.0.id, "high")
    }

    func testConsistentVariabilitySkipsJitterWithoutExclusions() {
        let low = makeTestExercise(id: "low", primaryMuscles: [.chest])
        let high = makeTestExercise(id: "high", primaryMuscles: [.chest])
        let scored: [(Exercise, Double)] = [(low, 10), (high, 20)]
        let ranked = WorkoutGenerationAlgorithms.rankScored(scored, variability: .consistent, avoidIds: [])
        XCTAssertEqual(ranked.map(\.0.id), ["high", "low"])
    }
}

final class WarmupSetPlannerTests: XCTestCase {
    func testLoadedExerciseGetsRampingWarmupSets() {
        let warmups = WarmupSetPlanner.warmupSets(workingWeight: 60, workingRepsMin: 8, rpeTarget: 8)
        XCTAssertEqual(warmups.count, 2)
        XCTAssertTrue(warmups.allSatisfy(\.isWarmup))
        XCTAssertEqual(warmups[0].targetWeightKg, 30)
        XCTAssertEqual(warmups[1].targetWeightKg, 45)
    }

    func testHeavyLoadGetsThreeWarmupSets() {
        let warmups = WarmupSetPlanner.warmupSets(workingWeight: 100, workingRepsMin: 5, rpeTarget: 8)
        XCTAssertEqual(warmups.count, 3)
        XCTAssertEqual(warmups.map(\.targetWeightKg), [40, 60, 80])
    }

    func testBodyweightExerciseGetsActivationSet() {
        let warmups = WarmupSetPlanner.warmupSets(workingWeight: nil, workingRepsMin: 10, rpeTarget: nil)
        XCTAssertEqual(warmups.count, 1)
        XCTAssertTrue(warmups[0].isWarmup)
        XCTAssertNil(warmups[0].targetWeightKg)
        XCTAssertEqual(warmups[0].targetRepsMin, 6)
    }

    func testGeneratedWorkoutIncludesWarmupsByDefault() async throws {
        let service = RulesWorkoutGenerationService()
        var profile = UserProfile.empty()
        profile.includeWarmupSets = true
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
            muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 80.0) }),
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(soreness: .none),
            splitDayFocus: .push
        )
        let workout = try await service.generate(input: input)
        XCTAssertFalse(workout.exercises.isEmpty)
        XCTAssertTrue(workout.exercises.contains { $0.targetSets.contains { $0.isWarmup } })
    }

    func testGeneratedWorkoutSkipsWarmupsWhenDisabled() async throws {
        let service = RulesWorkoutGenerationService()
        var profile = UserProfile.empty()
        profile.includeWarmupSets = false
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
            muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 80.0) }),
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(soreness: .none),
            splitDayFocus: .push
        )
        let workout = try await service.generate(input: input)
        XCTAssertFalse(workout.exercises.contains { $0.targetSets.contains { $0.isWarmup } })
    }
}

final class GoalAwareTitleTests: XCTestCase {
    func testStrengthGoalSuffixOnPushDay() {
        let title = WorkoutGenerationAlgorithms.workoutTitle(
            muscles: [.chest, .shoulders, .triceps],
            goal: .gainStrength,
            split: .pushPullLegs,
            focus: .push
        )
        XCTAssertEqual(title, "Push Strength")
    }

    func testFatLossGoalSuffixOnLowerBody() {
        let title = WorkoutGenerationAlgorithms.workoutTitle(
            muscles: [.quads, .hamstrings, .glutes],
            goal: .loseFat,
            split: .upperLower,
            focus: nil
        )
        XCTAssertEqual(title, "Lower Body Conditioning")
    }

    func testHypertrophyDefaultForBuildMuscle() {
        let title = WorkoutGenerationAlgorithms.workoutTitle(
            muscles: MuscleGroup.allCases,
            goal: .buildMuscle,
            split: .fullBody,
            focus: nil
        )
        XCTAssertEqual(title, "Full Body Hypertrophy")
    }
}

final class GeneratorValidatorDriftTests: XCTestCase {
    func testGeneratedWorkoutsPassValidationForSeededInputs() async throws {
        let service = RulesWorkoutGenerationService()
        let catalog = try await LocalExerciseRepository().fetchAll()
        var rng = SeededRandomNumberGenerator(seed: 2026)

        let goals = TrainingGoal.allCases
        let experiences = ExperienceLevel.allCases
        let focuses: [SplitDayFocus?] = [nil, .upper, .lower, .push, .pull, .legs, .fullBody]
        let durations = [30, 45, 60, 75]
        let sorenessLevels: [SorenessLevel] = [.none, .mild, .moderate]

        for iteration in 0..<24 {
            let goal = goals[Int(randomIndex(in: 0..<goals.count, using: &rng))]
            let experience = experiences[Int(randomIndex(in: 0..<experiences.count, using: &rng))]
            let focus = focuses[Int(randomIndex(in: 0..<focuses.count, using: &rng))]
            let duration = durations[Int(randomIndex(in: 0..<durations.count, using: &rng))]
            let soreness = sorenessLevels[Int(randomIndex(in: 0..<sorenessLevels.count, using: &rng))]
            let sleepScore = randomDouble(in: 55...90, using: &rng)

            var profile = UserProfile.empty()
            profile.goal = goal
            profile.experienceLevel = experience
            profile.preferredSessionLengthMinutes = duration

            let recovery = Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { muscle in
                (muscle, randomDouble(in: 50...95, using: &rng))
            })

            let input = WorkoutGenerationInput(
                userProfile: profile,
                goal: goal,
                experienceLevel: experience,
                availableEquipment: profile.availableEquipment,
                targetDurationMinutes: duration,
                preferredMuscleGroups: [],
                avoidedMuscleGroups: [],
                injuries: [],
                recentWorkouts: [],
                muscleRecovery: recovery,
                exerciseStats: [],
                userPreferences: WorkoutPreferences(),
                readiness: ReadinessInput(sleepScore: sleepScore, soreness: soreness),
                splitDayFocus: focus
            )

            let workout = try await service.generate(input: input)
            let validation = WorkoutValidator.validate(workout: workout, input: input, exercises: catalog)
            XCTAssertTrue(
                validation.errors.isEmpty,
                "Iteration \(iteration) failed: \(validation.errors.joined(separator: "; "))"
            )
        }
    }

    func testAdaptiveSplitGenerationPassesValidation() async throws {
        let service = RulesWorkoutGenerationService()
        let catalog = try await LocalExerciseRepository().fetchAll()
        var profile = UserProfile.empty()
        profile.preferredSplit = .adaptive

        let recovery = Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.enumerated().map { index, muscle in
            (muscle, 40.0 + Double(index))
        })

        let input = WorkoutGenerationInput(
            userProfile: profile,
            goal: .buildMuscle,
            experienceLevel: .intermediate,
            availableEquipment: profile.availableEquipment,
            targetDurationMinutes: 45,
            preferredMuscleGroups: [],
            avoidedMuscleGroups: [],
            injuries: [],
            recentWorkouts: [],
            muscleRecovery: recovery,
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(soreness: .none),
            splitDayFocus: nil
        )

        let workout = try await service.generate(input: input)
        let validation = WorkoutValidator.validate(workout: workout, input: input, exercises: catalog)
        XCTAssertTrue(validation.errors.isEmpty)
        XCTAssertNil(TrainingSchedule.currentSplitFocus(state: TrainingProgramState(), split: .adaptive))
        XCTAssertFalse(workout.exercises.isEmpty)
    }
}
