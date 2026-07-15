import XCTest
@testable import HotBod

final class MaxEffortPlannerTests: XCTestCase {
    func testShouldScheduleAfterEnoughSessions() {
        let stats = UserExerciseStats(
            exerciseId: "bench_press",
            lastWeightKg: 100,
            suggestedNextWeightKg: 100,
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8,
            sessionsSinceMaxEffort: GenerationConstants.MaxEffort.sessionsBetweenCalibration
        )
        XCTAssertTrue(MaxEffortPlanner.shouldScheduleMaxEffort(stats: stats, sessionMode: .standard))
    }

    func testShouldNotScheduleWithoutHistory() {
        XCTAssertFalse(MaxEffortPlanner.shouldScheduleMaxEffort(stats: nil, sessionMode: .standard))
    }

    func testMarksLastWorkingSet() {
        var sets = [
            PlannedSet(targetRepsMin: 8, targetRepsMax: 10, isWarmup: true),
            PlannedSet(targetRepsMin: 5, targetRepsMax: 8),
            PlannedSet(targetRepsMin: 5, targetRepsMax: 8)
        ]
        MaxEffortPlanner.markMaxEffortSet(in: &sets)
        XCTAssertFalse(sets[0].isMaxEffort)
        XCTAssertFalse(sets[1].isMaxEffort)
        XCTAssertTrue(sets[2].isMaxEffort)
    }

    func testRecalibratedWeightFromAMRAPSet() {
        let set = CompletedSet(setIndex: 2, weightKg: 100, reps: 8)
        let weight = MaxEffortPlanner.recalibratedWeight(from: set, equipment: [.barbell])
        let e1rm = ProgressiveOverload.estimateOneRepMax(weight: 100, reps: 8)
        let expected = GenerationConstants.Weight.roundToAvailable(
            e1rm * GenerationConstants.MaxEffort.workingWeightFraction,
            equipment: [.barbell]
        )
        XCTAssertEqual(weight ?? 0, expected, accuracy: 0.1)
    }

    func testRecalibratedWeightRespectsEquipmentCeiling() {
        let set = CompletedSet(setIndex: 2, weightKg: 100, reps: 8)
        let weight = MaxEffortPlanner.recalibratedWeight(
            from: set,
            equipment: [.dumbbell],
            ceilings: [.dumbbell: 22]
        )
        XCTAssertEqual(weight, 22)
    }
}

final class WorkoutSelectionRationaleTests: XCTestCase {
    func testBuildIncludesRecoveryLines() {
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
            muscleRecovery: [.chest: 92, .shoulders: 88],
            exerciseStats: [],
            userPreferences: WorkoutPreferences(exerciseVariability: .balanced),
            readiness: ReadinessInput(soreness: .none),
            splitDayFocus: .push
        )
        let lines = WorkoutSelectionRationale.build(
            input: input,
            muscles: [.chest, .shoulders],
            selectedExercises: [],
            sessionMode: .standard,
            filterOptions: WorkoutSelectionFilterContext()
        )
        XCTAssertTrue(lines.contains { $0.contains("Chest: 92% recovered") })
        XCTAssertTrue(lines.contains { $0.contains("Shoulders: 88% recovered") })
    }
}

final class LocalExerciseRepositoryCustomTests: XCTestCase {
    func testCreateAndFetchCustomExercise() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let repo = LocalExerciseRepository()
            let id = "custom_\(UUID().uuidString.lowercased().prefix(8))"
            let custom = Exercise(
                id: id,
                name: "My Press",
                slug: "my-press",
                primaryMuscles: [.chest],
                secondaryMuscles: [],
                equipment: [.dumbbell],
                movementPattern: .horizontalPush,
                difficulty: .intermediate,
                forceType: nil,
                mechanics: .compound,
                instructions: [],
                formCues: [],
                commonMistakes: [],
                contraindications: [],
                substitutions: [],
                progressions: [],
                regressions: [],
                demoVideos: [],
                imageUrl: nil,
                tags: ["custom"],
                isCustom: true
            )
            _ = try await repo.createCustomExercise(custom)
            let fetched = try await repo.fetch(id: id)
            XCTAssertEqual(fetched?.name, "My Press")
            XCTAssertTrue(fetched?.isCustom == true)
            try await repo.deleteCustomExercise(id: id)
        }
    }
}

final class AppGroupSessionStoreTests: XCTestCase {
    override func tearDown() {
        AppGroupSessionStore.resetTestingConfiguration()
        super.tearDown()
    }

    func testWriteAndReadSnapshot() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("hotbod-app-group-tests-\(UUID().uuidString)", isDirectory: true)
        AppGroupSessionStore.configureForTesting(containerURL: temp)
        defer { try? FileManager.default.removeItem(at: temp) }

        let snapshot = WatchSessionSnapshot(
            sessionId: UUID(),
            title: "Push Day",
            exerciseName: "Bench Press",
            exerciseIndex: 0,
            setIndex: 1,
            totalSets: 4,
            targetRepsMin: 8,
            targetRepsMax: 10,
            targetWeightKg: 80,
            isMaxEffort: false,
            restSecondsRemaining: 60,
            isResting: true,
            updatedAt: Date()
        )
        AppGroupSessionStore.writeSnapshot(snapshot)
        let read = AppGroupSessionStore.readSnapshot()
        XCTAssertEqual(read.title, "Push Day")
        XCTAssertEqual(read.exerciseName, "Bench Press")
    }
}
