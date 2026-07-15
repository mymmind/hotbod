import XCTest
@testable import HotBod

@MainActor
final class AppEnvironmentBootstrapTests: XCTestCase {
    func testFreshBootstrapLeavesOnboardingIncomplete() async {
        let env = AppEnvironment.makeForTests()
        await env.bootstrap()
        XCTAssertFalse(env.hasCompletedOnboarding)
        XCTAssertNil(env.userProfile)
    }

    func testBootstrapLoadsSavedProfile() async throws {
        var repos = TestRepositories.empty()
        var profile = UserProfile.empty()
        profile.name = "Persisted"
        try await repos.userProfile.saveProfile(profile)
        try await repos.userProfile.setOnboardingComplete(true)

        let env = AppEnvironment.makeForTests(repos: repos)
        await env.bootstrap()
        XCTAssertEqual(env.userProfile?.name, "Persisted")
        XCTAssertTrue(env.hasCompletedOnboarding)
    }

    func testBootstrapLoadsTodayWorkout() async throws {
        var repos = TestRepositories.withCatalog()
        let workout = FixtureBuilders.makeGeneratedWorkout()
        try await repos.workout.saveTodayWorkout(workout)

        let env = AppEnvironment.makeForTests(repos: repos)
        await env.bootstrap()
        XCTAssertEqual(env.todayWorkout?.id, workout.id)
    }

    func testBootstrapLoadsProgramState() async throws {
        var repos = TestRepositories.empty()
        var state = TrainingProgramState()
        state.splitDayIndex = 3
        try await repos.programState.saveState(state)

        let env = AppEnvironment.makeForTests(repos: repos)
        await env.bootstrap()
        XCTAssertEqual(env.programState.splitDayIndex, 3)
    }

    func testBootstrapLoadsRecoveryStates() async throws {
        var repos = TestRepositories.empty()
        var states = RecoveryCalculator.defaultStates()
        states[0].recoveryPercentage = 55
        try await repos.recovery.saveRecoveryStates(states)

        let env = AppEnvironment.makeForTests(repos: repos)
        await env.bootstrap()
        XCTAssertEqual(env.recoveryStates.first?.recoveryPercentage, 55)
    }

    func testBootstrapNormalizesRecoveryStates() async throws {
        var repos = TestRepositories.empty()
        var states = RecoveryCalculator.defaultStates()
        states[0].recoveryPercentage = 200
        try await repos.recovery.saveRecoveryStates(states)

        let env = AppEnvironment.makeForTests(repos: repos)
        await env.bootstrap()
        XCTAssertLessThanOrEqual(env.recoveryStates.first?.recoveryPercentage ?? 0, 100)
    }

    func testSeedOnboardedProfileMirrorsSkipOnboardingPath() async throws {
        let env = AppEnvironment.makeForTests()
        try await env.seedOnboardedProfile()
        XCTAssertTrue(env.hasCompletedOnboarding)
        XCTAssertNotNil(env.userProfile)
        XCTAssertFalse(env.recoveryStates.isEmpty)
        let persisted = try await env.userProfileRepository.isOnboardingComplete()
        XCTAssertTrue(persisted)
    }

    func testBootstrapAfterSeedOnboardedUsesPersistedProfile() async throws {
        var repos = TestRepositories.empty()
        let env = AppEnvironment.makeForTests(repos: repos)
        var profile = UserProfile.empty()
        profile.name = "UI Test User"
        try await env.seedOnboardedProfile(profile)
        env.todayWorkout = nil
        env.hasCompletedOnboarding = false
        env.userProfile = nil

        await env.bootstrap()
        XCTAssertEqual(env.userProfile?.name, "UI Test User")
        XCTAssertTrue(env.hasCompletedOnboarding)
    }
}

@MainActor
final class AppEnvironmentWorkoutGenerationTests: XCTestCase {
    private let exercises = [
        makeStubExercise(id: "bench_press", muscles: [.chest], pattern: .horizontalPush, equipment: [.barbell, .bench]),
        makeStubExercise(id: "dumbbell_press", muscles: [.chest], pattern: .horizontalPush, equipment: [.dumbbell, .bench]),
        makeStubExercise(id: "push_up", muscles: [.chest], pattern: .horizontalPush, equipment: [.bodyweight]),
        makeStubExercise(id: "cable_fly", muscles: [.chest], pattern: .isolation, equipment: [.cable])
    ]

    func testMakeWorkoutGenerationInputIncludesProfileGoal() async throws {
        var repos = TestRepositories.empty(exercises: exercises)
        var profile = UserProfile.empty()
        profile.goal = .loseFat
        let env = AppEnvironment.makeForTests(repos: repos)
        env.userProfile = profile
        env.recoveryStates = RecoveryCalculator.defaultStates()

        let input = await env.makeWorkoutGenerationInput(profile: profile, splitDayFocus: .push)
        XCTAssertEqual(input.goal, .loseFat)
        XCTAssertEqual(input.targetDurationMinutes, profile.preferredSessionLengthMinutes)
    }

    func testMakeWorkoutGenerationInputUsesInjectedStats() async throws {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        let stats = [UserExerciseStats(exerciseId: "bench_press", lastWeightKg: 80, preferredRepRangeMin: 5, preferredRepRangeMax: 8)]
        let input = await env.makeWorkoutGenerationInput(
            profile: UserProfile.empty(),
            splitDayFocus: nil,
            exerciseStats: stats
        )
        XCTAssertEqual(input.exerciseStats.count, 1)
        XCTAssertEqual(input.exerciseStats.first?.lastWeightKg, 80)
    }

    func testMakeWorkoutGenerationInputFiltersOrphanStats() async throws {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        var orphan = UserExerciseStats(exerciseId: "removed", preferredRepRangeMin: 5, preferredRepRangeMax: 8)
        orphan.isOrphaned = true
        let input = await env.makeWorkoutGenerationInput(
            profile: UserProfile.empty(),
            splitDayFocus: nil,
            exerciseStats: [orphan]
        )
        XCTAssertTrue(input.exerciseStats.isEmpty)
    }

    func testMakeWorkoutGenerationInputRespectsSorenessOption() async throws {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        let input = await env.makeWorkoutGenerationInput(
            profile: UserProfile.empty(),
            splitDayFocus: nil,
            soreness: .severe
        )
        XCTAssertEqual(input.readiness?.soreness, .severe)
    }

    func testRegression_generationAppliesScopedSorenessOnce() async {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        env.userProfile = UserProfile.empty()
        env.recoveryStates = RecoveryCalculator.defaultStates()
        let recent = [
            WorkoutSessionSummary(
                id: UUID(),
                title: "Push",
                completedAt: Date(),
                totalVolumeKg: 1000,
                totalSets: 12,
                durationMinutes: 45,
                muscleGroups: [.chest]
            )
        ]
        let input = await env.makeWorkoutGenerationInput(
            profile: UserProfile.empty(),
            splitDayFocus: nil,
            recentWorkouts: recent,
            soreness: .severe
        )
        XCTAssertEqual(input.muscleRecovery[.chest], 70)
        XCTAssertEqual(input.muscleRecovery[.quads], 85)
    }

    func testRegression_generationDoesNotApplyLegacyFlatSorenessPenalty() async {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        env.userProfile = UserProfile.empty()
        env.recoveryStates = RecoveryCalculator.defaultStates()
        let input = await env.makeWorkoutGenerationInput(
            profile: UserProfile.empty(),
            splitDayFocus: nil,
            recentWorkouts: [],
            soreness: .severe
        )
        XCTAssertEqual(input.muscleRecovery[.quads], 85)
        XCTAssertNotEqual(input.muscleRecovery[.quads], 80)
    }

    func testGenerateWorkoutReturnsMockWorkout() async {
        let workout = FixtureBuilders.makeGeneratedWorkout()
        let mock = FixedMockWorkoutGenerationService(workout: workout)
        let env = AppEnvironment.makeForTests(
            repos: .empty(exercises: exercises),
            workoutGenerationService: mock
        )
        env.recoveryStates = RecoveryCalculator.defaultStates()
        let generated = await env.generateWorkout(profile: UserProfile.empty(), splitDayFocus: .push)
        XCTAssertEqual(generated?.id, workout.id)
    }

    func testGenerateWorkoutRejectsInvalidValidation() async {
        let workout = FixtureBuilders.makeGeneratedWorkout()
        let mock = FixedMockWorkoutGenerationService(
            workout: workout,
            validationResult: WorkoutValidationResult(isValid: false, errors: ["bad"], warnings: [], suggestions: [])
        )
        let env = AppEnvironment.makeForTests(workoutGenerationService: mock)
        env.recoveryStates = RecoveryCalculator.defaultStates()
        let generated = await env.generateWorkout(profile: UserProfile.empty(), splitDayFocus: nil)
        XCTAssertNil(generated)
        XCTAssertFalse(env.lastValidation?.isValid ?? true)
    }

    func testGenerateWorkoutStoresLastValidation() async {
        let workout = FixtureBuilders.makeGeneratedWorkout()
        let mock = FixedMockWorkoutGenerationService(workout: workout)
        let env = AppEnvironment.makeForTests(workoutGenerationService: mock)
        env.recoveryStates = RecoveryCalculator.defaultStates()
        _ = await env.generateWorkout(profile: UserProfile.empty(), splitDayFocus: nil)
        XCTAssertTrue(env.lastValidation?.isValid ?? false)
    }

    func testPersistRegeneratedWorkoutSavesToRepository() async throws {
        let workout = FixtureBuilders.makeGeneratedWorkout()
        let mock = FixedMockWorkoutGenerationService(workout: workout)
        var repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos, workoutGenerationService: mock)
        env.recoveryStates = RecoveryCalculator.defaultStates()

        let saved = await env.persistRegeneratedWorkout(
            profile: UserProfile.empty(),
            splitDayFocus: .push,
            options: WorkoutGenerationOptions()
        )
        XCTAssertTrue(saved)
        XCTAssertEqual(env.todayWorkout?.id, workout.id)
        let persisted = try await repos.workout.fetchTodayWorkout()
        XCTAssertEqual(persisted?.id, workout.id)
    }

    func testPersistRegeneratedWorkoutReturnsFalseWhenGenerationFails() async {
        let mock = FixedMockWorkoutGenerationService(
            workout: FixtureBuilders.makeGeneratedWorkout(),
            validationResult: WorkoutValidationResult(isValid: false, errors: ["fail"], warnings: [], suggestions: [])
        )
        let env = AppEnvironment.makeForTests(workoutGenerationService: mock)
        env.recoveryStates = RecoveryCalculator.defaultStates()
        let saved = await env.persistRegeneratedWorkout(
            profile: UserProfile.empty(),
            splitDayFocus: nil,
            options: WorkoutGenerationOptions()
        )
        XCTAssertFalse(saved)
        XCTAssertNil(env.todayWorkout)
    }

    func testRegression_trainAnywayGeneratesOnUnscheduledDay() async {
        let workout = FixtureBuilders.makeGeneratedWorkout()
        let generator = FixedMockWorkoutGenerationService(workout: workout)
        let env = AppEnvironment.makeForTests(workoutGenerationService: generator)
        let today = TrainingSchedule.weekday()
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(2))
        profile.trainingDaysPerWeek = 2
        env.userProfile = profile
        env.recoveryStates = RecoveryCalculator.defaultStates()

        let generated = await env.generateTodayWorkoutOnRestDay(profile: profile)

        XCTAssertTrue(generated)
        XCTAssertEqual(env.todayWorkout?.id, workout.id)
    }

    func testRegression_normalRegenerationRemainsBlockedOnUnscheduledDay() async {
        let generator = FixedMockWorkoutGenerationService(workout: FixtureBuilders.makeGeneratedWorkout())
        let env = AppEnvironment.makeForTests(workoutGenerationService: generator)
        let today = TrainingSchedule.weekday()
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(2))
        profile.trainingDaysPerWeek = 2

        let generated = await env.regenerateTodayWorkout(profile: profile)

        XCTAssertFalse(generated)
        XCTAssertNil(env.todayWorkout)
    }

    func testRegression_readinessRefreshRegeneratesTrainingDayWorkout() async {
        let workout = FixtureBuilders.makeGeneratedWorkout()
        let generator = FixedMockWorkoutGenerationService(workout: workout)
        let env = AppEnvironment.makeForTests(workoutGenerationService: generator)
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = [TrainingSchedule.weekday(), .wednesday]
        profile.trainingDaysPerWeek = 2
        env.userProfile = profile
        env.todayWorkout = workout
        env.recoveryStates = RecoveryCalculator.defaultStates()

        let refreshed = await env.refreshTodayWorkoutForReadinessChange(profile: profile)

        XCTAssertTrue(refreshed)
        XCTAssertEqual(env.todayWorkout?.id, workout.id)
    }

    func testRegression_readinessRefreshUsesTrainAnywayOnRestDayWithWorkout() async {
        let workout = FixtureBuilders.makeGeneratedWorkout()
        let generator = FixedMockWorkoutGenerationService(workout: workout)
        let env = AppEnvironment.makeForTests(workoutGenerationService: generator)
        let today = TrainingSchedule.weekday()
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(2))
        profile.trainingDaysPerWeek = 2
        env.userProfile = profile
        env.todayWorkout = workout
        env.recoveryStates = RecoveryCalculator.defaultStates()

        let refreshed = await env.refreshTodayWorkoutForReadinessChange(profile: profile)

        XCTAssertTrue(refreshed)
        XCTAssertEqual(env.todayWorkout?.id, workout.id)
    }

    func testRegression_readinessRefreshSkipsBareRestDay() async {
        let generator = FixedMockWorkoutGenerationService(workout: FixtureBuilders.makeGeneratedWorkout())
        let env = AppEnvironment.makeForTests(workoutGenerationService: generator)
        let today = TrainingSchedule.weekday()
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(2))
        profile.trainingDaysPerWeek = 2
        env.userProfile = profile
        env.recoveryStates = RecoveryCalculator.defaultStates()

        let refreshed = await env.refreshTodayWorkoutForReadinessChange(profile: profile)

        XCTAssertFalse(refreshed)
        XCTAssertNil(env.todayWorkout)
    }
}

@MainActor
final class AppEnvironmentDayRolloverTests: XCTestCase {
    func testRegression_revalidateOnResumeRegeneratesStaleWorkoutFromYesterday() async throws {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let staleWorkout = FixtureBuilders.makeGeneratedWorkout(createdAt: yesterday)
        let freshWorkout = FixtureBuilders.makeGeneratedWorkout()
        let generator = FixedMockWorkoutGenerationService(workout: freshWorkout)
        var repos = TestRepositories.empty()
        try await repos.workout.saveTodayWorkout(staleWorkout)

        let env = AppEnvironment.makeForTests(repos: repos, workoutGenerationService: generator)
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = [TrainingSchedule.weekday(), .wednesday]
        try await env.seedOnboardedProfile(profile)
        env.todayWorkout = staleWorkout

        var state = TrainingProgramState()
        state.todayCompletedSessionId = UUID()
        state.todayCompletedOn = TrainingSchedule.startOfDay(yesterday)
        state.todayRotationAdvancedOn = TrainingSchedule.startOfDay(yesterday)
        env.programState = state

        await env.revalidateTodayPlanForCurrentDay()

        XCTAssertEqual(env.todayWorkout?.id, freshWorkout.id, "stale workout should be regenerated on day rollover")
        XCTAssertNil(env.programState.todayCompletedOn, "yesterday's completion marker should be cleared")
        XCTAssertNil(env.programState.todayRotationAdvancedOn, "yesterday's rotation marker should be cleared")
    }
}

@MainActor
final class AppEnvironmentLifecycleTests: XCTestCase {
    func testConcurrentRefreshDayScopedStateCoalescesCloudPull() async throws {
        let cloud = CountingCloudSyncService()
        let env = AppEnvironment.makeForTests(cloudSyncService: cloud)
        try await env.seedOnboardedProfile()
        env.isSignedIn = true
        env.hasCompletedBootstrap = true

        async let first: Void = env.refreshDayScopedState(pullCloudFirst: true)
        async let second: Void = env.refreshDayScopedState(pullCloudFirst: true)
        _ = await (first, second)

        XCTAssertEqual(cloud.pullCount, 1)
    }

    func testRefreshDayScopedStateMergesNewerLocalDecayAfterCloudPull() async throws {
        let older = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let newer = Date()
        var cloudState = TrainingProgramState()
        cloudState.lastRecoveryDecayAppliedAt = older

        let repos = TestRepositories.empty()
        let cloud = ProgramStatePullCloudSyncService(pulledProgramState: cloudState)
        let env = AppEnvironment.makeForTests(repos: repos, cloudSyncService: cloud)
        try await env.seedOnboardedProfile()
        env.isSignedIn = true
        env.hasCompletedBootstrap = true
        env.programState.lastRecoveryDecayAppliedAt = newer

        await env.refreshDayScopedState(pullCloudFirst: true)

        XCTAssertNotEqual(env.programState.lastRecoveryDecayAppliedAt, older)
        XCTAssertGreaterThanOrEqual(env.programState.lastRecoveryDecayAppliedAt ?? .distantPast, newer)
    }

    func testMergeDecayReferenceAfterCloudPullKeepsNewerLocalTimestamp() async throws {
        let older = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let newer = Date()
        let repos = TestRepositories.empty()
        let env = AppEnvironment.makeForTests(repos: repos)
        try await env.seedOnboardedProfile()

        var cloudState = TrainingProgramState()
        cloudState.lastRecoveryDecayAppliedAt = older
        try await repos.programState.saveState(cloudState)
        env.programState.lastRecoveryDecayAppliedAt = newer

        await env.mergeDecayReferenceAfterCloudPull(local: newer)

        XCTAssertEqual(env.programState.lastRecoveryDecayAppliedAt, newer)
    }

    func testShouldRegenerateStaleWorkoutBlockedWhileStartingSession() async throws {
        let env = AppEnvironment.makeForTests()
        try await env.seedOnboardedProfile()
        env.isStartingWorkoutSession = true

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let staleWorkout = FixtureBuilders.makeGeneratedWorkout(createdAt: yesterday)

        let shouldRegenerate = await env.shouldRegenerateStaleTodayWorkout(staleWorkout)
        XCTAssertFalse(shouldRegenerate)
    }

    func testRegression_regenerateUIButtonNotBlockedByGenerationReservation() async throws {
        let env = AppEnvironment.makeForTests(repos: TestRepositories.withCatalog())
        try await env.seedOnboardedProfile()
        await env.bootstrap()

        env.isReservingWorkoutGeneration = true
        XCTAssertFalse(env.isWorkoutGenerationInFlight)
    }

    func testBootstrapAndRegenerateOnTrainingDay() async throws {
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = [TrainingSchedule.weekday()]
        let fresh = FixtureBuilders.makeGeneratedWorkout()
        let env = AppEnvironment.makeForTests(
            repos: TestRepositories.withCatalog(),
            workoutGenerationService: FixedMockWorkoutGenerationService(workout: fresh)
        )
        try await env.seedOnboardedProfile(profile)
        await env.bootstrap()

        XCTAssertNotNil(env.todayWorkout)
        let regenerated = await env.regenerateTodayWorkout(profile: profile)
        XCTAssertTrue(regenerated)
    }

    func testRegression_regenerateOnRestDayWhenWorkoutExists() async throws {
        let today = TrainingSchedule.weekday()
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = Weekday.allCases.filter { $0 != today }
        let fresh = FixtureBuilders.makeGeneratedWorkout()
        let env = AppEnvironment.makeForTests(
            repos: TestRepositories.withCatalog(),
            workoutGenerationService: FixedMockWorkoutGenerationService(workout: fresh)
        )
        try await env.seedOnboardedProfile(profile)
        env.todayWorkout = fresh
        try await env.workoutRepository.saveTodayWorkout(fresh)

        XCTAssertFalse(TrainingSchedule.isTrainingDay(profile: profile))

        let regenerated = await env.regenerateTodayWorkout(profile: profile)
        XCTAssertTrue(regenerated)
        XCTAssertNotNil(env.todayWorkout)
    }

    func testRulesEngineRegenerateAfterBootstrap() async throws {
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = [TrainingSchedule.weekday(), .monday, .tuesday, .thursday, .friday]
        let env = AppEnvironment.makeForTests(repos: TestRepositories.withCatalog())
        try await env.seedOnboardedProfile(profile)
        await env.bootstrap()

        XCTAssertNotNil(env.todayWorkout, "bootstrap should create today's workout")
        XCTAssertFalse(env.isWorkoutGenerationInFlight)
        XCTAssertFalse(env.isWorkoutGenerationReserved)

        let regenerated = await env.regenerateTodayWorkout(profile: profile)
        if !regenerated {
            XCTFail(
                "regenerate failed: failure=\(String(describing: env.lastGenerationFailure)) " +
                "validation=\(String(describing: env.lastValidation))"
            )
        }
        XCTAssertTrue(regenerated)
        XCTAssertNotNil(env.todayWorkout)
    }

    func testRulesEngineTrainAnywayOnRestDayAfterOnboarding() async throws {
        let today = TrainingSchedule.weekday()
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(4))
        profile.trainingDaysPerWeek = profile.preferredTrainingDays.count

        let env = AppEnvironment.makeForTests(repos: TestRepositories.withCatalog())
        try await env.seedOnboardedProfile(profile)
        await env.bootstrap()

        XCTAssertTrue(env.isRestDay)
        XCTAssertNil(env.todayWorkout)

        let generated = await env.generateTodayWorkoutOnRestDay(profile: profile)
        if !generated {
            XCTFail(
                "train anyway failed: failure=\(String(describing: env.lastGenerationFailure)) " +
                "validation=\(String(describing: env.lastValidation))"
            )
        }
        XCTAssertTrue(generated)
        XCTAssertNotNil(env.todayWorkout)
        XCTAssertFalse(env.todayWorkout?.exercises.isEmpty ?? true)
    }

    func testRegression_stuckGenerationActiveDoesNotBlockRegenerate() async throws {
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = [TrainingSchedule.weekday(), .monday, .tuesday, .thursday, .friday]
        let env = AppEnvironment.makeForTests(repos: TestRepositories.withCatalog())
        try await env.seedOnboardedProfile(profile)
        await env.bootstrap()

        env.isWorkoutGenerationActive = true
        let regenerated = await env.regenerateTodayWorkout(profile: profile)
        XCTAssertTrue(regenerated)
        XCTAssertFalse(env.isWorkoutGenerationInFlight)
    }

    func testRulesEngineRegenerateAfterTrainAnywayOnRestDay() async throws {
        let today = TrainingSchedule.weekday()
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(4))
        profile.trainingDaysPerWeek = profile.preferredTrainingDays.count

        let env = AppEnvironment.makeForTests(repos: TestRepositories.withCatalog())
        try await env.seedOnboardedProfile(profile)
        await env.bootstrap()

        let trained = await env.generateTodayWorkoutOnRestDay(profile: profile)
        XCTAssertTrue(trained)
        let originalId = try XCTUnwrap(env.todayWorkout?.id)
        let originalExerciseIds = try XCTUnwrap(env.todayWorkout?.exercises.map(\.exerciseId))

        let regenerated = await env.regenerateTodayWorkout(profile: profile)
        if !regenerated {
            XCTFail(
                "regenerate after train anyway failed: failure=\(String(describing: env.lastGenerationFailure)) " +
                "validation=\(String(describing: env.lastValidation)) paywall=\(String(describing: env.paywallFeature))"
            )
        }
        XCTAssertTrue(regenerated)
        XCTAssertNotEqual(env.todayWorkout?.id, originalId)
        XCTAssertNotEqual(env.todayWorkout?.exercises.map(\.exerciseId), originalExerciseIds)
    }

    func testRegression_restDayRegenerateWorksWhenFreeQuotaExhausted() async throws {
        let today = TrainingSchedule.weekday()
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(4))
        profile.trainingDaysPerWeek = profile.preferredTrainingDays.count

        let repos = TestRepositories.withCatalog()
        let env = AppEnvironment(
            workoutRepository: repos.workout,
            exerciseRepository: repos.exercise,
            nutritionRepository: repos.nutrition,
            bodyProgressRepository: repos.bodyProgress,
            userProfileRepository: repos.userProfile,
            recoveryRepository: repos.recovery,
            exerciseStatsRepository: repos.exerciseStats,
            programStateRepository: repos.programState,
            coachRepository: repos.coach,
            workoutGenerationService: RulesWorkoutGenerationService(exerciseRepository: repos.exercise),
            subscriptionService: ForgeSubscriptionService(grantProForTesting: false)
        )
        try await env.seedOnboardedProfile(profile)
        env.programState.weeklyRegenerationCount = FreeTierLimits.weeklyRegenerations
        await env.bootstrap()

        let first = await env.generateTodayWorkoutOnRestDay(profile: profile)
        XCTAssertTrue(first)
        let originalId = try XCTUnwrap(env.todayWorkout?.id)

        let second = await env.generateTodayWorkoutOnRestDay(profile: profile)
        XCTAssertTrue(second)
        XCTAssertNotEqual(env.todayWorkout?.id, originalId)
        XCTAssertNil(env.paywallFeature)
    }
}

@MainActor
final class AppEnvironmentWorkoutSessionTests: XCTestCase {
    private let exercises = [
        makeTestExercise(id: "bench_press"),
        makeTestExercise(id: "dumbbell_press")
    ]

    func testResumeOrStartWorkoutSetsActiveSessionAfterPersistingSession() async throws {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        try await env.seedOnboardedProfile()
        let workout = FixtureBuilders.makeGeneratedWorkout()

        let session = await env.resumeOrStartWorkout(from: workout)
        XCTAssertNotNil(session)
        XCTAssertEqual(env.programState.activeSessionId, session?.id)

        let persisted = try await repos.workout.fetchSessions()
        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(persisted.first?.id, session?.id)
    }

    func testResumeOrStartWorkoutDoesNotSetActiveSessionWhenSaveFails() async throws {
        let repos = TestRepositories.empty(exercises: exercises)
        let failingRepo = FailingSaveWorkoutRepository(wrapped: repos.workout)
        let env = AppEnvironment(
            workoutRepository: failingRepo,
            exerciseRepository: repos.exercise,
            nutritionRepository: repos.nutrition,
            bodyProgressRepository: repos.bodyProgress,
            userProfileRepository: repos.userProfile,
            recoveryRepository: repos.recovery,
            exerciseStatsRepository: repos.exerciseStats,
            programStateRepository: repos.programState,
            coachRepository: repos.coach,
            subscriptionService: ForgeSubscriptionService(grantProForTesting: true)
        )
        try await env.seedOnboardedProfile()
        let session = await env.resumeOrStartWorkout(from: FixtureBuilders.makeGeneratedWorkout())
        XCTAssertNil(session)
        XCTAssertNil(env.programState.activeSessionId)
    }

    func testResumeOrStartWorkoutCreatesSession() async throws {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        try await env.seedOnboardedProfile()
        let workout = FixtureBuilders.makeGeneratedWorkout()

        let session = await env.resumeOrStartWorkout(from: workout)
        XCTAssertNotNil(session)
        XCTAssertNotNil(session?.startedAt)
        XCTAssertEqual(session?.status, .inProgress)
        XCTAssertEqual(env.programState.activeSessionId, session?.id)
        let persisted = try await repos.workout.fetchSessions()
        XCTAssertEqual(persisted.count, 1)
    }

    func testResumeOrStartWorkoutReturnsExistingActiveSession() async throws {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        try await env.seedOnboardedProfile()
        let workout = FixtureBuilders.makeGeneratedWorkout()
        let first = await env.resumeOrStartWorkout(from: workout)
        let second = await env.resumeOrStartWorkout(from: workout)
        XCTAssertEqual(first?.id, second?.id)
    }

    func testResumeOrStartWorkoutNilWithoutProfile() async {
        let env = AppEnvironment.makeForTests()
        let session = await env.resumeOrStartWorkout(from: FixtureBuilders.makeGeneratedWorkout())
        XCTAssertNil(session)
    }

    func testResumeOrStartWorkoutDefersStartTimestampWhenRequested() async throws {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        try await env.seedOnboardedProfile()
        let workout = FixtureBuilders.makeGeneratedWorkout()

        let session = await env.resumeOrStartWorkout(from: workout, deferStartTimestamp: true)

        XCTAssertNotNil(session)
        XCTAssertNil(session?.startedAt)
    }

    func testCommitWorkoutSessionStartIfNeededSetsStartedAt() async throws {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        try await env.seedOnboardedProfile()
        let workout = FixtureBuilders.makeGeneratedWorkout()
        let pending = await env.resumeOrStartWorkout(from: workout, deferStartTimestamp: true)
        XCTAssertNotNil(pending?.startedAt == nil)

        let started = await env.commitWorkoutSessionStartIfNeeded(pending!)
        XCTAssertNotNil(started.startedAt)

        let persisted = try await repos.workout.fetchSessions().first { $0.id == started.id }
        XCTAssertNotNil(persisted?.startedAt)
    }

    func testCommitWorkoutSessionStartIfNeededIsIdempotent() async throws {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        try await env.seedOnboardedProfile()
        let workout = FixtureBuilders.makeGeneratedWorkout()
        let session = await env.resumeOrStartWorkout(from: workout)
        let firstStartedAt = session?.startedAt

        let committed = await env.commitWorkoutSessionStartIfNeeded(session!)
        XCTAssertEqual(committed.startedAt, firstStartedAt)
    }

    func testApplyWorkoutSessionCompletionUpdatesStats() async throws {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        try await env.seedOnboardedProfile()
        var session = FixtureBuilders.makeWorkoutSession()
        session.exercises[0].completedSets = [
            CompletedSet(setIndex: 0, weightKg: 60, reps: 8)
        ]

        let notes = await env.applyWorkoutSessionCompletion(session)
        let stats = try await repos.exerciseStats.fetchStats()
        XCTAssertEqual(stats.first?.exerciseId, "bench_press")
        XCTAssertFalse(notes.isEmpty)
    }

    func testApplyWorkoutSessionCompletionUpdatesRecovery() async throws {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        try await env.seedOnboardedProfile()
        let baseline = env.recoveryStates.first { $0.muscleGroup == .chest }!.recoveryPercentage
        var session = FixtureBuilders.makeWorkoutSession()
        session.exercises[0].completedSets = [
            CompletedSet(setIndex: 0, weightKg: 60, reps: 8)
        ]

        _ = await env.applyWorkoutSessionCompletion(session)
        let after = env.recoveryStates.first { $0.muscleGroup == .chest }!.recoveryPercentage
        XCTAssertLessThan(after, baseline)
    }

    func testApplyWorkoutSessionCompletionSkipsSkippedExercises() async throws {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        try await env.seedOnboardedProfile()
        var session = FixtureBuilders.makeWorkoutSession()
        session.exercises[0].wasSkipped = true
        session.exercises[0].completedSets = [
            CompletedSet(setIndex: 0, weightKg: 60, reps: 8)
        ]

        _ = await env.applyWorkoutSessionCompletion(session)
        let stats = try await repos.exerciseStats.fetchStats()
        XCTAssertTrue(stats.isEmpty)
    }

    func testRefreshWorkoutAfterSessionClearsActiveSession() async throws {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        try await env.seedOnboardedProfile()
        let session = await env.resumeOrStartWorkout(from: FixtureBuilders.makeGeneratedWorkout())!
        await env.refreshWorkoutAfterSession(session)
        XCTAssertNil(env.programState.activeSessionId)
    }

    func testRefreshWorkoutAfterSessionMarksTodayCompleted() async throws {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        try await env.seedOnboardedProfile()
        let session = await env.resumeOrStartWorkout(from: FixtureBuilders.makeGeneratedWorkout())!
        await env.refreshWorkoutAfterSession(session)
        XCTAssertEqual(env.programState.todayCompletedSessionId, session.id)
        XCTAssertNotNil(env.programState.todayCompletedOn)
    }

    func testRefreshWorkoutAfterSessionAdvancesRotation() async throws {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        var profile = UserProfile.empty()
        profile.preferredSplit = .upperLower
        try await env.seedOnboardedProfile(profile)
        var session = FixtureBuilders.makeWorkoutSession()
        session.splitDayFocus = .upper
        session.status = .completed
        session.completedAt = Date()
        await env.refreshWorkoutAfterSession(session)
        XCTAssertEqual(env.programState.splitDayIndex, 1)
    }
}

@MainActor
final class AppEnvironmentOnboardingAndCoachTests: XCTestCase {
    private let exercises = [
        makeStubExercise(id: "a", muscles: [.chest], pattern: .horizontalPush, equipment: [.barbell]),
        makeStubExercise(id: "b", muscles: [.chest], pattern: .horizontalPush, equipment: [.dumbbell]),
        makeStubExercise(id: "c", muscles: [.chest], pattern: .horizontalPush, equipment: [.cable]),
        makeStubExercise(id: "d", muscles: [.chest], pattern: .isolation, equipment: [.cable]),
        makeStubExercise(id: "e", muscles: [.chest], pattern: .horizontalPush, equipment: [.dumbbell])
    ]

    func testCompleteOnboardingPersistsProfileAndFlag() async throws {
        let repos = TestRepositories.empty()
        let env = AppEnvironment.makeForTests(repos: repos)
        var profile = UserProfile.empty()
        profile.name = "New User"
        try await env.completeOnboarding(profile: profile)

        XCTAssertTrue(env.hasCompletedOnboarding)
        XCTAssertEqual(env.userProfile?.name, "New User")
        let onboardingComplete = try await repos.userProfile.isOnboardingComplete()
        XCTAssertTrue(onboardingComplete)
    }

    func testCompleteOnboardingSetsRecoveryDefaults() async throws {
        let env = AppEnvironment.makeForTests()
        try await env.completeOnboarding(profile: UserProfile.empty())
        XCTAssertEqual(env.recoveryStates.count, RecoveryCalculator.defaultStates().count)
    }

    func testRegression_onboardingCompletionDoesNotAddToday() async {
        let env = AppEnvironment.makeForTests()
        let today = TrainingSchedule.weekday()
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(2))
        profile.trainingDaysPerWeek = 2

        _ = await env.finishOnboardingAndStartTodayWorkout(profile: profile)

        XCTAssertEqual(env.userProfile?.preferredTrainingDays, profile.preferredTrainingDays)
        XCTAssertFalse(env.userProfile?.preferredTrainingDays.contains(today) ?? true)
        XCTAssertTrue(env.hasCompletedOnboarding)
    }

    func testRegression_finishOnboardingWithoutWorkoutLeavesProfileSaved() async throws {
        let repos = TestRepositories.withCatalog()
        let env = AppEnvironment.makeForTests(
            repos: repos,
            workoutGenerationService: FailingMockWorkoutGenerationService()
        )
        var profile = UserProfile.empty()
        let today = TrainingSchedule.weekday()
        let anotherDay = Weekday.allCases.first { $0 != today }!
        profile.preferredTrainingDays = [today, anotherDay]
        profile.trainingDaysPerWeek = 2

        let session = await env.finishOnboardingAndStartTodayWorkout(profile: profile)

        XCTAssertTrue(env.hasCompletedOnboarding)
        XCTAssertNil(session)
        XCTAssertNil(env.todayWorkout)
        XCTAssertNotNil(env.syncMessage)
    }

    func testBlocksCoachWorkoutModificationWithActiveSession() async throws {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        try await env.seedOnboardedProfile()
        _ = await env.resumeOrStartWorkout(from: FixtureBuilders.makeGeneratedWorkout())
        let blocked = await env.blocksCoachWorkoutModification()
        XCTAssertTrue(blocked)
    }

    func testBlocksCoachWorkoutModificationWithCompletedSetsToday() async throws {
        let repos = TestRepositories.empty(exercises: exercises)
        let env = AppEnvironment.makeForTests(repos: repos)
        try await env.seedOnboardedProfile()
        var session = FixtureBuilders.makeWorkoutSession(status: .completed)
        session.exercises[0].completedSets = [
            CompletedSet(setIndex: 0, weightKg: 50, reps: 10, completedAt: Date())
        ]
        try await repos.workout.saveSession(session)
        let blocked = await env.blocksCoachWorkoutModification()
        XCTAssertTrue(blocked)
    }

    func testBlocksCoachWorkoutModificationFalseWhenClear() async throws {
        let env = AppEnvironment.makeForTests(repos: .empty(exercises: exercises))
        try await env.seedOnboardedProfile()
        let blocked = await env.blocksCoachWorkoutModification()
        XCTAssertFalse(blocked)
    }

    func testTryAutoApplyCoachModificationRejectsNonModifyIntent() async throws {
        let env = AppEnvironment.makeForTests(repos: .empty(exercises: exercises))
        try await env.seedOnboardedProfile()
        let result = CoachAIResult(
            message: CoachMessage(id: UUID(), role: .assistant, content: "Hi", createdAt: Date(), intent: .generalTrainingQuestion),
            proposedWorkout: nil
        )
        let applied = await env.tryAutoApplyCoachModification(result: result, allowedExerciseIds: ["a", "b", "c", "d", "e"])
        XCTAssertFalse(applied)
    }

    func testTryAutoApplyCoachModificationAppliesSafeWorkout() async throws {
        let current = makeOrchestrationWorkout(duration: 45, exerciseIds: ["a", "b", "c", "d"])
        let proposed = makeOrchestrationWorkout(duration: 30, exerciseIds: ["a", "b", "e", "d"])
        let mock = FixedMockWorkoutGenerationService(workout: proposed)
        let env = AppEnvironment.makeForTests(repos: .empty(exercises: exercises), workoutGenerationService: mock)
        try await env.seedOnboardedProfile()
        env.todayWorkout = current

        let result = CoachAIResult(
            message: CoachMessage(id: UUID(), role: .assistant, content: "Swapped C for E", createdAt: Date(), intent: .modifyWorkout),
            proposedWorkout: proposed,
            validation: WorkoutValidationResult(isValid: true, errors: [], warnings: [], suggestions: [])
        )
        let applied = await env.tryAutoApplyCoachModification(result: result, allowedExerciseIds: exercises.map(\.id))
        XCTAssertTrue(applied)
        XCTAssertEqual(env.todayWorkout?.exercises.map(\.exerciseId), ["a", "b", "e", "d"])
    }

    func testTryAutoApplyCoachModificationBlockedDuringSession() async throws {
        let proposed = makeOrchestrationWorkout(duration: 30, exerciseIds: ["a", "b", "c", "d"])
        let env = AppEnvironment.makeForTests(repos: .empty(exercises: exercises))
        try await env.seedOnboardedProfile()
        env.todayWorkout = makeOrchestrationWorkout(duration: 45, exerciseIds: ["a", "b", "c", "d"])
        _ = await env.resumeOrStartWorkout(from: env.todayWorkout!)

        let result = CoachAIResult(
            message: CoachMessage(id: UUID(), role: .assistant, content: "Change", createdAt: Date(), intent: .modifyWorkout),
            proposedWorkout: proposed,
            validation: WorkoutValidationResult(isValid: true, errors: [], warnings: [], suggestions: [])
        )
        let applied = await env.tryAutoApplyCoachModification(result: result, allowedExerciseIds: exercises.map(\.id))
        XCTAssertFalse(applied)
        XCTAssertNotNil(env.coachWorkoutUpdateMessage)
    }

    private func makeOrchestrationWorkout(duration: Int, exerciseIds: [String]) -> GeneratedWorkout {
        GeneratedWorkout(
            id: UUID(),
            title: "Coach Test",
            estimatedDurationMinutes: duration,
            focus: [.chest],
            exercises: exerciseIds.enumerated().map { index, id in
                PlannedExercise(
                    exerciseId: id,
                    orderIndex: index,
                    targetSets: Array(repeating: PlannedSet(targetRepsMin: 8, targetRepsMax: 10), count: 3)
                )
            },
            rationale: "",
            safetyNotes: [],
            generatedBy: .aiAssisted,
            createdAt: Date()
        )
    }
}

final class SettingsDraftEditingRefreshTests: XCTestCase {
    func testShouldRefreshWorkoutOnGoalChange() {
        var draft = UserProfile.empty()
        var original = UserProfile.empty()
        draft.goal = .loseFat
        XCTAssertTrue(SettingsDraftEditing.shouldRefreshWorkout(draft: draft, comparedTo: original))
    }

    func testShouldRefreshWorkoutOnEquipmentChange() {
        var draft = UserProfile.empty()
        let original = UserProfile.empty()
        draft.availableEquipment = [.dumbbell]
        XCTAssertTrue(SettingsDraftEditing.shouldRefreshWorkout(draft: draft, comparedTo: original))
    }

    func testShouldRefreshWorkoutOnSplitChange() {
        var draft = UserProfile.empty()
        let original = UserProfile.empty()
        draft.preferredSplit = .pushPullLegs
        XCTAssertTrue(SettingsDraftEditing.shouldRefreshWorkout(draft: draft, comparedTo: original))
    }

    func testShouldRefreshWorkoutOnLimitationsChange() {
        var draft = UserProfile.empty()
        let original = UserProfile.empty()
        draft.limitations = [.knee]
        XCTAssertTrue(SettingsDraftEditing.shouldRefreshWorkout(draft: draft, comparedTo: original))
    }

    func testShouldNotRefreshWorkoutOnNameOnlyChange() {
        var draft = UserProfile.empty()
        let original = UserProfile.empty()
        draft.name = "Renamed"
        XCTAssertFalse(SettingsDraftEditing.shouldRefreshWorkout(draft: draft, comparedTo: original))
    }

    func testShouldNotRefreshWorkoutOnProteinGoalChange() {
        var draft = UserProfile.empty()
        let original = UserProfile.empty()
        draft.proteinGoalGrams = 200
        XCTAssertFalse(SettingsDraftEditing.shouldRefreshWorkout(draft: draft, comparedTo: original))
    }
}

@MainActor
final class SettingsDraftEditingScheduleTests: XCTestCase {
    func testRegression_settingsScheduleAlwaysDerivesFrequencyFromSelectedDays() {
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = [.monday, .wednesday, .friday]
        profile.trainingDaysPerWeek = 6

        SettingsDraftEditing.reconcileSchedule(&profile)

        XCTAssertEqual(profile.preferredTrainingDays, [.monday, .wednesday, .friday])
        XCTAssertEqual(profile.trainingDaysPerWeek, 3)
    }

    func testRegression_settingsScheduleCannotDropBelowTwoDays() {
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = [.monday, .wednesday]
        profile.trainingDaysPerWeek = 2

        let changed = SettingsDraftEditing.toggleTrainingDay(.monday, in: &profile)

        XCTAssertFalse(changed)
        XCTAssertEqual(profile.preferredTrainingDays, [.monday, .wednesday])
        XCTAssertEqual(profile.trainingDaysPerWeek, 2)
    }
}

@MainActor
final class AppEnvironmentRecoveryRegressionTests: XCTestCase {
    func testRegression_repeatedRecoveryDecayDoesNotCompoundSoreness() async {
        let env = AppEnvironment.makeForTests()
        env.userProfile = UserProfile.empty()
        env.sorenessLevel = .severe
        env.recoveryStates = RecoveryCalculator.defaultStates()
        let baseline = env.recoveryStates.first { $0.muscleGroup == .chest }!.recoveryPercentage

        await env.applyRecoveryDecay(now: Date())
        await env.applyRecoveryDecay(now: Date())

        let chest = env.recoveryStates.first { $0.muscleGroup == .chest }!
        XCTAssertEqual(chest.recoveryPercentage, baseline, accuracy: 0.01)
    }

    func testRegression_changingSorenessDoesNotMutatePersistedRecovery() {
        let env = AppEnvironment.makeForTests()
        env.userProfile = UserProfile.empty()
        env.recoveryStates = RecoveryCalculator.defaultStates()
        let baseline = env.recoveryStates.first { $0.muscleGroup == .chest }!.recoveryPercentage

        env.setSoreness(.severe)

        let chest = env.recoveryStates.first { $0.muscleGroup == .chest }!
        XCTAssertEqual(chest.recoveryPercentage, baseline)
        XCTAssertEqual(env.sorenessLevel, .severe)
    }
}

@MainActor
final class AppEnvironmentAccountDeletionTests: XCTestCase {
    func testWipeAllLocalUserDataClearsRuntimeStateAndPersistence() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistenceOnMainActor {
            var profile = UserProfile.empty()
            profile.name = "Delete Me"
            PersistenceHelper.save(profile, to: "user_profile.json")
            PersistenceHelper.save(true, to: "onboarding_complete.json")

            let env = AppEnvironment.makeForTests()
            env.userProfile = profile
            env.hasCompletedOnboarding = true
            env.todayWorkout = FixtureBuilders.makeGeneratedWorkout()
            env.isSignedIn = true
            env.authEmail = "test@example.com"

            try await env.wipeAllLocalUserData()

            XCTAssertNil(env.userProfile)
            XCTAssertNil(env.todayWorkout)
            XCTAssertFalse(env.hasCompletedOnboarding)
            XCTAssertFalse(env.isSignedIn)
            XCTAssertNil(env.authEmail)
            XCTAssertNil(PersistenceHelper.load(UserProfile.self, from: "user_profile.json"))
            XCTAssertNil(PersistenceHelper.load(Bool.self, from: "onboarding_complete.json"))
        }
    }

    func testWipeAllLocalUserDataResetsExercisePreferences() async throws {
        let repos = TestRepositories.withCatalog()
        let env = AppEnvironment.makeForTests(repos: repos)
        let all = try await repos.exercise.fetchAll()
        let favoriteId = all[0].id
        let lessId = all[1].id
        try await repos.exercise.updatePreference(id: favoriteId, preference: .favorite)
        try await repos.exercise.updatePreference(id: lessId, preference: .less)

        try await env.wipeAllLocalUserData()

        let favorite = try await repos.exercise.fetch(id: favoriteId)
        let less = try await repos.exercise.fetch(id: lessId)
        XCTAssertEqual(favorite?.preference, .neutral)
        XCTAssertEqual(less?.preference, .neutral)
    }

    func testDeleteAccountSkipsRemoteWhenAuthUnavailable() async throws {
        let env = AppEnvironment.makeForTests()
        env.isSignedIn = true
        env.authEmail = "test@example.com"
        env.userProfile = UserProfile.empty()
        env.hasCompletedOnboarding = true

        try await env.deleteAccount()

        XCTAssertNil(env.userProfile)
        XCTAssertFalse(env.hasCompletedOnboarding)
        XCTAssertFalse(env.isSignedIn)
    }

    func testRegression_deleteAccountClearsAuthSessionWhenAuthAvailable() async throws {
        let auth = TrackingAuthService()
        let env = AppEnvironment.makeForTests(authService: auth)
        env.isSignedIn = true
        env.authEmail = "test@example.com"
        env.userProfile = UserProfile.empty()
        env.hasCompletedOnboarding = true

        try await env.deleteAccount()

        XCTAssertTrue(auth.didDeleteAccount)
        XCTAssertTrue(auth.didSignOut)
        XCTAssertFalse(env.isSignedIn)
        XCTAssertNil(env.authEmail)
    }

    func testRegression_wipeRemovesCustomExercisesFromMemory() async throws {
        let repos = TestRepositories.withCatalog()
        let env = AppEnvironment.makeForTests(repos: repos)
        let custom = makeStubExercise(
            id: "custom_test_lift",
            muscles: [.chest],
            pattern: .horizontalPush,
            equipment: [.dumbbell]
        )
        _ = try await repos.exercise.createCustomExercise(custom)

        try await env.wipeAllLocalUserData()

        let all = try await repos.exercise.fetchAll()
        XCTAssertFalse(all.contains { $0.id == custom.id })
    }
}

private final class TrackingAuthService: AuthService, @unchecked Sendable {
    var isAvailable: Bool { true }
    private(set) var didSignOut = false
    private(set) var didDeleteAccount = false

    func currentUserId() async -> UUID? { UUID() }
    func currentEmail() async -> String? { "test@example.com" }
    func signUp(email: String, password: String) async throws {}
    func signIn(email: String, password: String) async throws {}
    func signOut() async throws { didSignOut = true }
    func deleteAccount() async throws { didDeleteAccount = true }
    func restoreSession() async -> Bool { false }
}
