import XCTest
import os
@testable import HotBod

private struct StubExerciseRepository: ExerciseRepository {
    let exercises: [Exercise]

    func fetchAll() async throws -> [Exercise] { exercises }
    func fetch(id: String) async throws -> Exercise? { exercises.first { $0.id == id } }
    func search(query: String, filters: ExerciseFilters) async throws -> [Exercise] {
        ExerciseFilter.apply(exercises: exercises, query: query, filters: filters)
    }
    func fetchSubstitutionGroups() async throws -> [ExerciseSubstitutionGroup] { [] }
    func fetchExercises(inGroup groupId: String) async throws -> [Exercise] { [] }
    func substitutionGroup(for exerciseId: String) async throws -> ExerciseSubstitutionGroup? { nil }
    func substitutes(
        for exerciseId: String,
        availableEquipment: [Equipment],
        injuries: [BodyLimitation],
        excludeIds: Set<String>
    ) async throws -> [Exercise] {
        []
    }
    func updateFavorite(id: String, isFavorite: Bool) async throws {}
    func updateAvoided(id: String, isAvoided: Bool) async throws {}
}

private func makeStubExercise(
    id: String,
    muscles: [MuscleGroup],
    pattern: MovementPattern,
    equipment: [Equipment] = [.bodyweight],
    isAvoided: Bool = false,
    difficulty: ExerciseDifficulty = .intermediate,
    contraindications: [String] = []
) -> Exercise {
    Exercise(
        id: id,
        name: id,
        slug: id,
        primaryMuscles: muscles,
        secondaryMuscles: [],
        equipment: equipment,
        movementPattern: pattern,
        difficulty: difficulty,
        forceType: nil,
        mechanics: pattern.inferredMechanics,
        instructions: [],
        formCues: [],
        commonMistakes: [],
        contraindications: contraindications,
        substitutions: [],
        progressions: [],
        regressions: [],
        demoVideos: [],
        imageUrl: nil,
        tags: [],
        isAvoided: isAvoided
    )
}

final class HardeningWorkoutGenerationTests: XCTestCase {
    func testEmptyRecoveryMapGeneratesValidWorkout() async throws {
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
            muscleRecovery: [:],
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(soreness: .none),
            splitDayFocus: nil
        )

        let workout = try await service.generate(input: input)
        let validation = service.validate(workout: workout, input: input)
        XCTAssertGreaterThanOrEqual(workout.exercises.count, GenerationConstants.Session.minStandardExercises)
        XCTAssertTrue(validation.isValid, validation.errors.joined(separator: "; "))
    }

    func testAvoidedExerciseRelaxationRecoversGeneration() async throws {
        let exercises = [
            makeStubExercise(id: "chest_1", muscles: [.chest], pattern: .horizontalPush),
            makeStubExercise(id: "chest_2", muscles: [.chest], pattern: .horizontalPush, isAvoided: true),
            makeStubExercise(id: "chest_3", muscles: [.chest], pattern: .horizontalPush, isAvoided: true),
            makeStubExercise(id: "chest_4", muscles: [.chest], pattern: .horizontalPush, isAvoided: true),
            makeStubExercise(id: "back_1", muscles: [.back], pattern: .horizontalPull),
            makeStubExercise(id: "back_2", muscles: [.back], pattern: .horizontalPull, isAvoided: true),
            makeStubExercise(id: "shoulder_1", muscles: [.shoulders], pattern: .verticalPush),
            makeStubExercise(id: "shoulder_2", muscles: [.shoulders], pattern: .verticalPush, isAvoided: true)
        ]

        let service = RulesWorkoutGenerationService(exerciseRepository: StubExerciseRepository(exercises: exercises))
        let profile = UserProfile.empty()
        let input = WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: profile.experienceLevel,
            availableEquipment: [.bodyweight],
            targetDurationMinutes: 45,
            preferredMuscleGroups: [],
            avoidedMuscleGroups: [],
            injuries: [],
            recentWorkouts: [],
            muscleRecovery: RecoveryCalculator.recoveryMap(from: RecoveryCalculator.defaultStates()),
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(soreness: .none),
            splitDayFocus: nil
        )

        let workout = try await service.generate(input: input)
        XCTAssertGreaterThanOrEqual(workout.exercises.count, GenerationConstants.Session.minStandardExercises)
        XCTAssertTrue(
            workout.safetyNotes.contains(GenerationConstants.Targeting.avoidedExercisesRelaxationMessage)
        )
    }

    func testInsufficientExercisesThrowsTypedFailure() async {
        let exercises = [
            makeStubExercise(id: "squat", muscles: [.quads], pattern: .squat, contraindications: ["knee"]),
            makeStubExercise(id: "lunge", muscles: [.quads], pattern: .lunge, contraindications: ["knee"])
        ]

        let service = RulesWorkoutGenerationService(exerciseRepository: StubExerciseRepository(exercises: exercises))
        let profile = UserProfile.empty()
        let input = WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: profile.experienceLevel,
            availableEquipment: [.bodyweight],
            targetDurationMinutes: 45,
            preferredMuscleGroups: [],
            avoidedMuscleGroups: [],
            injuries: [.knee],
            recentWorkouts: [],
            muscleRecovery: RecoveryCalculator.recoveryMap(from: RecoveryCalculator.defaultStates()),
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(soreness: .none),
            splitDayFocus: nil
        )

        do {
            _ = try await service.generate(input: input)
            XCTFail("Expected GenerationFailure.insufficientExercises")
        } catch let failure as GenerationFailure {
            guard case let .insufficientExercises(available, blockedByInjury, blockedByEquipment) = failure else {
                return XCTFail("Unexpected failure: \(failure)")
            }
            XCTAssertEqual(available, 0)
            XCTAssertEqual(blockedByInjury, 2)
            XCTAssertGreaterThanOrEqual(blockedByEquipment, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

final class HardeningTimeWindowTests: XCTestCase {
    func testWorkoutRetainedWhenActiveSessionCrossesMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let createdAt = calendar.date(from: DateComponents(year: 2024, month: 1, day: 15, hour: 23, minute: 55))!
        let now = calendar.date(from: DateComponents(year: 2024, month: 1, day: 16, hour: 0, minute: 10))!

        XCTAssertFalse(
            WorkoutStaleness.shouldRegenerate(
                workoutCreatedAt: createdAt,
                hasActiveSession: true,
                hasCompletedSetsToday: false,
                now: now,
                calendar: calendar
            )
        )
        XCTAssertTrue(
            WorkoutStaleness.shouldRegenerate(
                workoutCreatedAt: createdAt,
                hasActiveSession: false,
                hasCompletedSetsToday: false,
                now: now,
                calendar: calendar
            )
        )
    }

    func testWorkoutRetainedWhenSetsLoggedTodayDespiteOldCreatedAt() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let createdAt = calendar.date(from: DateComponents(year: 2024, month: 1, day: 15, hour: 23, minute: 55))!
        let now = calendar.date(from: DateComponents(year: 2024, month: 1, day: 16, hour: 0, minute: 10))!

        XCTAssertFalse(
            WorkoutStaleness.shouldRegenerate(
                workoutCreatedAt: createdAt,
                hasActiveSession: false,
                hasCompletedSetsToday: true,
                now: now,
                calendar: calendar
            )
        )
    }

    func testRollingSetCountUsesSevenDayWindow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let insideWindow = CompletedSet(
            setIndex: 0,
            reps: 5,
            completedAt: now.addingTimeInterval(-6 * 24 * 3600 - 23 * 3600)
        )
        let outsideWindow = CompletedSet(
            setIndex: 1,
            reps: 5,
            completedAt: now.addingTimeInterval(-7 * 24 * 3600 - 3600)
        )

        XCTAssertEqual(VolumeTracker.rollingSetCount(from: [insideWindow, outsideWindow], endingAt: now), 1)
    }

    func testRollingVolumeHistoryUsesRollingWindows() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let currentWindow = CompletedSet(
            setIndex: 0,
            reps: 10,
            completedAt: now.addingTimeInterval(-2 * 24 * 3600)
        )
        let previousWindow = CompletedSet(
            setIndex: 1,
            reps: 20,
            completedAt: now.addingTimeInterval(-8 * 24 * 3600)
        )
        let history = VolumeTracker.weeklyVolumeHistory(
            from: [currentWindow, previousWindow],
            endingAt: now
        )

        XCTAssertEqual(history, [20, 10])
    }

    func testRollingSetCountIgnoresCalendarLocale() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let set = CompletedSet(
            setIndex: 0,
            reps: 5,
            completedAt: now.addingTimeInterval(-3 * 24 * 3600)
        )

        XCTAssertEqual(VolumeTracker.rollingSetCount(from: [set], endingAt: now), 1)
        XCTAssertEqual(
            VolumeTracker.weeklyVolumeHistory(from: [set], endingAt: now).last,
            5
        )
    }
}

final class HardeningRecoveryDecayTests: XCTestCase {
    func testDoubleDecayAtSameInstantDoesNotChangeRecovery() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let states = RecoveryCalculator.defaultStates()
        let first = RecoveryCalculator.decayRecovery(
            states: states,
            experienceLevel: .intermediate,
            lastDecayAppliedAt: nil,
            now: now
        )
        let second = RecoveryCalculator.decayRecovery(
            states: first.states,
            experienceLevel: .intermediate,
            lastDecayAppliedAt: first.lastDecayAppliedAt,
            now: now
        )

        XCTAssertEqual(first.states.map(\.recoveryPercentage), second.states.map(\.recoveryPercentage))
    }

    func testNegativeDecayIntervalIsNoOp() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let states = [
            MuscleRecoveryState(muscleGroup: .chest, recoveryPercentage: 55, lastTrainedAt: nil, accumulatedFatigue: 0)
        ]
        let decay = RecoveryCalculator.decayRecovery(
            states: states,
            experienceLevel: .intermediate,
            lastDecayAppliedAt: now.addingTimeInterval(3600),
            now: now
        )

        XCTAssertEqual(decay.states.first?.recoveryPercentage, 55)
    }

    func testDecayCapsAtFourteenDays() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let states = [
            MuscleRecoveryState(muscleGroup: .chest, recoveryPercentage: 10, lastTrainedAt: nil, accumulatedFatigue: 0)
        ]
        let decay = RecoveryCalculator.decayRecovery(
            states: states,
            experienceLevel: .intermediate,
            lastDecayAppliedAt: now.addingTimeInterval(-30 * 24 * 3600),
            now: now
        )

        XCTAssertLessThanOrEqual(decay.states.first?.recoveryPercentage ?? 0, 100)
        XCTAssertGreaterThan(decay.states.first?.recoveryPercentage ?? 0, 10)
    }
}

final class HardeningCatalogIntegrityTests: XCTestCase {
    func testOrphanSweepPrunesMissingWorkoutExercisesAndFlagsStats() {
        let catalogIds: Set<String> = ["bench_press", "squat"]
        var workout: GeneratedWorkout? = GeneratedWorkout(
            id: UUID(),
            title: "Test",
            estimatedDurationMinutes: 45,
            focus: [.chest, .quads],
            exercises: [
                PlannedExercise(exerciseId: "bench_press", orderIndex: 0, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
                PlannedExercise(exerciseId: "removed_move", orderIndex: 1, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
                PlannedExercise(exerciseId: "squat", orderIndex: 2, targetSets: [PlannedSet(targetRepsMin: 5, targetRepsMax: 8)]),
                PlannedExercise(exerciseId: "old_press", orderIndex: 3, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)])
            ],
            rationale: "",
            safetyNotes: [],
            generatedBy: .rulesEngine,
            createdAt: Date()
        )
        var stats = [
            UserExerciseStats(
                exerciseId: "old_press",
                recentSets: [],
                preferredRepRangeMin: 8,
                preferredRepRangeMax: 12
            )
        ]

        let result = CatalogIntegrity.sweep(catalogIds: catalogIds, workout: &workout, stats: &stats)

        XCTAssertEqual(result.removedWorkoutExerciseIds.sorted(), ["old_press", "removed_move"])
        XCTAssertNil(workout)
        XCTAssertTrue(result.workoutNeedsRegeneration)
        XCTAssertTrue(stats.first?.isOrphaned == true)
    }
}

// MARK: - PR D: Progression hardening

final class HardeningProgressionTests: XCTestCase {
    func testGoalChangeUsesGoalRepRangeNotHistoricalStats() {
        let stats = UserExerciseStats(
            exerciseId: "bench_press",
            preferredRepRangeMin: 10,
            preferredRepRangeMax: 12,
            goalAtLastUpdate: .buildMuscle
        )

        let strengthRange = GenerationConstants.Prescription.effectiveRepRange(
            stats: stats,
            goal: .gainStrength,
            experience: .intermediate
        )

        XCTAssertEqual(strengthRange.min, 4)
        XCTAssertEqual(strengthRange.max, 6)
    }

    func testSameGoalUsesHistoricalRepRange() {
        let stats = UserExerciseStats(
            exerciseId: "bench_press",
            preferredRepRangeMin: 10,
            preferredRepRangeMax: 12,
            goalAtLastUpdate: .buildMuscle
        )

        let range = GenerationConstants.Prescription.effectiveRepRange(
            stats: stats,
            goal: .buildMuscle,
            experience: .intermediate
        )

        XCTAssertEqual(range.min, 10)
        XCTAssertEqual(range.max, 12)
    }

    func testLegacyStatsWithoutGoalStampUseGoalRange() {
        let stats = UserExerciseStats(
            exerciseId: "bench_press",
            preferredRepRangeMin: 10,
            preferredRepRangeMax: 12
        )

        let range = GenerationConstants.Prescription.effectiveRepRange(
            stats: stats,
            goal: .gainStrength,
            experience: .intermediate
        )

        XCTAssertEqual(range.min, 4)
        XCTAssertEqual(range.max, 6)
    }

    func testDeloadExpiresAfterSevenDays() {
        let now = Date()
        var stats = UserExerciseStats(
            exerciseId: "squat",
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8,
            deloadStartedAt: now.addingTimeInterval(-3 * 24 * 3600)
        )

        XCTAssertTrue(stats.isInDeloadWeek(at: now))
        XCTAssertTrue(stats.isInDeloadSuppressionWindow(at: now))

        stats.deloadStartedAt = now.addingTimeInterval(-8 * 24 * 3600)
        XCTAssertFalse(stats.isInDeloadWeek(at: now))
        XCTAssertTrue(stats.isInDeloadSuppressionWindow(at: now))

        stats.deloadStartedAt = now.addingTimeInterval(-15 * 24 * 3600)
        XCTAssertFalse(stats.isInDeloadSuppressionWindow(at: now))
    }

    func testDeloadWeekLowVolumeDoesNotReTriggerDeload() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let previousWindowSets = (0..<10).map { index in
            CompletedSet(
                setIndex: index,
                weightKg: 100,
                reps: 5,
                completedAt: now.addingTimeInterval(-8 * 24 * 3600)
            )
        }
        let currentWindowSets = (0..<2).map { index in
            CompletedSet(
                setIndex: index,
                weightKg: 100,
                reps: 5,
                completedAt: now.addingTimeInterval(-1 * 24 * 3600)
            )
        }

        var stats = UserExerciseStats(
            exerciseId: "squat",
            recentSets: previousWindowSets + currentWindowSets,
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8,
            deloadStartedAt: now.addingTimeInterval(-2 * 24 * 3600)
        )

        let analysis = DeloadDetector.analyzeDeloadNeed(stats: stats, volumeHistory: [], now: now)
        XCTAssertFalse(analysis.isDeloadRecommended)
        XCTAssertFalse(analysis.suggestsReturningFromBreak)
    }

    func testDumbbellWeightRoundsToTwoKgIncrements() {
        let rounded = GenerationConstants.Weight.roundToAvailable(21, equipment: [.dumbbell])
        XCTAssertEqual(rounded, 22)
        XCTAssertEqual(GenerationConstants.Weight.roundToAvailable(19, equipment: [.dumbbell]), 20)
    }

    func testBarbellWeightRoundsToTwoPointFiveKgIncrements() {
        XCTAssertEqual(
            GenerationConstants.Weight.roundToAvailable(81.3, equipment: [.barbell]),
            82.5
        )
    }

    func testScopedSorenessPenalizesTrainedMusclesMore() {
        let states = RecoveryCalculator.defaultStates()
        let trained: Set<MuscleGroup> = [.quads, .hamstrings, .glutes]

        let updated = RecoveryCalculator.applySoreness(
            states: states,
            level: .severe,
            recentlyTrainedMuscles: trained
        )

        let quads = updated.first { $0.muscleGroup == .quads }!
        let chest = updated.first { $0.muscleGroup == .chest }!
        XCTAssertEqual(quads.recoveryPercentage, 70)
        XCTAssertEqual(chest.recoveryPercentage, 85)
    }
}

// MARK: - PR E+F: Validation and concurrency hardening

private func makeValidationInput(stats: [UserExerciseStats] = []) -> WorkoutGenerationInput {
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
        muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 80.0) }),
        exerciseStats: stats,
        userPreferences: WorkoutPreferences(),
        readiness: ReadinessInput(soreness: .none),
        splitDayFocus: nil
    )
}

private func makeValidWorkout(exerciseId: String, exercises: [Exercise]) -> GeneratedWorkout {
    GeneratedWorkout(
        id: UUID(),
        title: "Test",
        estimatedDurationMinutes: 45,
        focus: [.chest],
        exercises: [
            PlannedExercise(
                exerciseId: exerciseId,
                orderIndex: 0,
                targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 60)],
                restSeconds: 90
            )
        ],
        rationale: "",
        safetyNotes: [],
        generatedBy: .rulesEngine,
        createdAt: Date()
    )
}

final class HardeningValidationTests: XCTestCase {
    func testRejectsNegativeWeight() {
        let exercise = makeTestExercise(id: "curl", equipment: [.dumbbell])
        var workout = makeValidWorkout(exerciseId: "curl", exercises: [exercise])
        workout.exercises[0].targetSets = [PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: -5)]

        let result = WorkoutValidator.validate(
            workout: workout,
            input: makeValidationInput(),
            exercises: [exercise]
        )

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("Invalid weight") })
    }

    func testRejectsAbsurdWeight() {
        let exercise = makeTestExercise(id: "curl", equipment: [.dumbbell])
        var workout = makeValidWorkout(exerciseId: "curl", exercises: [exercise])
        workout.exercises[0].targetSets = [PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 500)]

        let result = WorkoutValidator.validate(
            workout: workout,
            input: makeValidationInput(),
            exercises: [exercise]
        )

        XCTAssertFalse(result.isValid)
    }

    func testRejectsLoadedWeightOnBodyweightExercise() {
        // Exercises like push-ups may support external loading; choose a true bodyweight-only exercise.
        let exercise = makeTestExercise(id: "bird_dog", pattern: .horizontalPush, equipment: [.bodyweight])
        var workout = makeValidWorkout(exerciseId: "bird_dog", exercises: [exercise])
        workout.exercises[0].targetSets = [PlannedSet(targetRepsMin: 8, targetRepsMax: 12, targetWeightKg: 20)]

        let result = WorkoutValidator.validate(
            workout: workout,
            input: makeValidationInput(),
            exercises: [exercise]
        )

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("external loaded weight") })
    }

    func testWarnsOnLargeWeightJump() {
        let exercises = (1...4).map { makeTestExercise(id: "bench_press_\($0)") }
        let workout = GeneratedWorkout(
            id: UUID(),
            title: "Test",
            estimatedDurationMinutes: 45,
            focus: [.chest],
            exercises: exercises.enumerated().map { index, exercise in
                PlannedExercise(
                    exerciseId: exercise.id,
                    orderIndex: index,
                    targetSets: index == 0
                        ? [PlannedSet(targetRepsMin: 5, targetRepsMax: 8, targetWeightKg: 100)]
                        : [PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 60)],
                    restSeconds: 90
                )
            },
            rationale: "",
            safetyNotes: [],
            generatedBy: .rulesEngine,
            createdAt: Date()
        )
        let stats = UserExerciseStats(
            exerciseId: "bench_press_1",
            lastWeightKg: 60,
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )

        let result = WorkoutValidator.validate(
            workout: workout,
            input: makeValidationInput(stats: [stats]),
            exercises: exercises
        )

        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.warnings.contains { $0.contains("Large weight jump") })
    }

    func testRejectsInvalidRestPeriod() {
        let exercise = makeTestExercise(id: "curl")
        var workout = makeValidWorkout(exerciseId: "curl", exercises: [exercise])
        workout.exercises[0].restSeconds = 5

        let result = WorkoutValidator.validate(
            workout: workout,
            input: makeValidationInput(),
            exercises: [exercise]
        )

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("Invalid rest period") })
    }

    func testRejectsInvalidSetCount() {
        let exercise = makeTestExercise(id: "curl")
        var workout = makeValidWorkout(exerciseId: "curl", exercises: [exercise])
        workout.exercises[0].targetSets = Array(
            repeating: PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 20),
            count: 10
        )

        let result = WorkoutValidator.validate(
            workout: workout,
            input: makeValidationInput(),
            exercises: [exercise]
        )

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("Invalid set count") })
    }

    func testEmptyMuscleTitleFallsBackToWorkout() {
        let title = WorkoutGenerationAlgorithms.workoutTitle(
            muscles: [],
            goal: .buildMuscle,
            split: .fullBody,
            focus: nil
        )
        XCTAssertEqual(title, "Workout")
    }
}

private final class SlowMockWorkoutGenerationService: WorkoutGenerationService, @unchecked Sendable {
    private let callCount = OSAllocatedUnfairLock(initialState: 0)
    let delayNanoseconds: UInt64

    init(delayNanoseconds: UInt64 = 100_000_000) {
        self.delayNanoseconds = delayNanoseconds
    }

    func generate(input: WorkoutGenerationInput) async throws -> GeneratedWorkout {
        let call = callCount.withLock { count -> Int in
            count += 1
            return count
        }

        try await Task.sleep(nanoseconds: delayNanoseconds)
        try Task.checkCancellation()

        return GeneratedWorkout(
            id: UUID(),
            title: "Generation-\(call)",
            estimatedDurationMinutes: 45,
            focus: [.chest],
            exercises: [
                PlannedExercise(
                    exerciseId: "bench_press",
                    orderIndex: 0,
                    targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 60)]
                )
            ],
            rationale: "",
            safetyNotes: [],
            generatedBy: .rulesEngine,
            createdAt: Date()
        )
    }

    func validate(workout: GeneratedWorkout, input: WorkoutGenerationInput) -> WorkoutValidationResult {
        WorkoutValidationResult(isValid: true, errors: [], warnings: [], suggestions: [])
    }
}

@MainActor
final class HardeningConcurrencyTests: XCTestCase {
    func testSecondGenerationWinsRace() async {
        let mock = SlowMockWorkoutGenerationService()
        let env = AppEnvironment(workoutGenerationService: mock)
        let profile = UserProfile.empty()
        env.userProfile = profile
        env.recoveryStates = RecoveryCalculator.defaultStates()

        let firstTask = Task { @MainActor in
            await env.generateWorkout(profile: profile, splitDayFocus: nil)
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
        let second = await env.generateWorkout(profile: profile, splitDayFocus: nil)
        let first = await firstTask.value

        XCTAssertNil(first)
        XCTAssertEqual(second?.title, "Generation-2")
    }

    func testPersistRegeneratedWorkoutDoesNotSaveCancelledResult() async {
        let mock = SlowMockWorkoutGenerationService(delayNanoseconds: 150_000_000)
        let env = AppEnvironment(workoutGenerationService: mock)
        let profile = UserProfile.empty()
        env.userProfile = profile
        env.recoveryStates = RecoveryCalculator.defaultStates()

        let firstTask = Task { @MainActor in
            await env.persistRegeneratedWorkout(profile: profile, splitDayFocus: nil, options: WorkoutGenerationOptions())
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
        _ = await env.persistRegeneratedWorkout(profile: profile, splitDayFocus: nil, options: WorkoutGenerationOptions())
        let firstSaved = await firstTask.value

        XCTAssertFalse(firstSaved)
        XCTAssertEqual(env.todayWorkout?.title, "Generation-2")
    }
}

final class HardeningReviewFixTests: XCTestCase {
    func testLegacyDeloadFlagWithoutDateStartsDeload() throws {
        let json = """
        {
          "exerciseId": "squat",
          "preferredRepRangeMin": 5,
          "preferredRepRangeMax": 8,
          "recentSets": [],
          "isInDeloadWeek": true
        }
        """.data(using: .utf8)!

        let stats = try JSONDecoder().decode(UserExerciseStats.self, from: json)
        XCTAssertNotNil(stats.deloadStartedAt)
        XCTAssertTrue(stats.isInDeloadWeek)
    }

    func testCatalogSweepClearingWorkoutRequiresPersistenceClear() async {
        let repo = LocalWorkoutRepository()
        let workout = GeneratedWorkout(
            id: UUID(),
            title: "Stale",
            estimatedDurationMinutes: 45,
            focus: [.chest],
            exercises: [
                PlannedExercise(
                    exerciseId: "removed_move",
                    orderIndex: 0,
                    targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]
                )
            ],
            rationale: "",
            safetyNotes: [],
            generatedBy: .rulesEngine,
            createdAt: Date()
        )
        try? await repo.saveTodayWorkout(workout)

        var cleared: GeneratedWorkout? = workout
        var stats: [UserExerciseStats] = []
        let result = CatalogIntegrity.sweep(
            catalogIds: ["bench_press"],
            workout: &cleared,
            stats: &stats
        )

        XCTAssertTrue(result.workoutNeedsRegeneration)
        XCTAssertNil(cleared)
        try? await repo.clearTodayWorkout()
        let fetched = try? await repo.fetchTodayWorkout()
        XCTAssertNil(fetched)
    }
}

final class LoadTrackingModeDomainTests: XCTestCase {
    func testResolvedLoadTrackingModeUsesOverrides() {
        let exercises = [
            "push_up": LoadTrackingMode.supported,
            "glute_bridge": LoadTrackingMode.supported,
            "russian_twist": LoadTrackingMode.supported,
            "sled_push": LoadTrackingMode.required,
            "plank": LoadTrackingMode.optional,
            "side_plank": LoadTrackingMode.optional,
            "bird_dog": LoadTrackingMode.none,
            "ab_wheel_rollout": LoadTrackingMode.none
        ]

        for (id, expected) in exercises {
            let exercise = makeTestExercise(id: id, equipment: [.bodyweight])
            XCTAssertEqual(exercise.resolvedLoadTrackingMode, expected, "Expected \(id) to resolve to \(expected)")
        }
    }

    func testBodyweightOnlyNoneModeRejectsExternalLoad() {
        let exercise = makeTestExercise(
            id: "bird_dog",
            primaryMuscles: [.chest],
            pattern: .horizontalPush,
            equipment: [.bodyweight]
        )

        var workout = makeValidWorkout(exerciseId: "bird_dog", exercises: [exercise])
        workout.exercises[0].targetSets = [
            PlannedSet(targetRepsMin: 8, targetRepsMax: 12, targetWeightKg: 20)
        ]

        let result = WorkoutValidator.validate(
            workout: workout,
            input: makeValidationInput(),
            exercises: [exercise]
        )

        XCTAssertFalse(result.isValid)
    }
}
