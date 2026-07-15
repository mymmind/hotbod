import XCTest
@testable import HotBod

@MainActor
// swiftlint:disable:next type_body_length
final class IntegrationFlowTests: XCTestCase {
  // MARK: - Cold start → first workout

  func testColdStartBootstrapGeneratesFirstWorkoutOnTrainingDay() async throws {
    let env = makeEnvironment()
    var profile = UserProfile.empty()
    profile.preferredTrainingDays = [TrainingSchedule.weekday(), .monday, .tuesday, .thursday, .friday]

    try await env.seedOnboardedProfile(profile)
    await env.bootstrap()

    XCTAssertTrue(env.hasCompletedOnboarding)
    XCTAssertNotNil(env.todayWorkout)
    XCTAssertFalse(env.todayWorkout?.exercises.isEmpty ?? true)
    XCTAssertTrue(env.lastValidation?.isValid ?? false)
  }

  func testColdStartWithoutOnboardingSkipsWorkoutGeneration() async throws {
    let env = makeEnvironment()

    await env.bootstrap()

    XCTAssertFalse(env.hasCompletedOnboarding)
    XCTAssertNil(env.todayWorkout)
  }

  func testColdStartOnRestDayDoesNotGenerateWorkout() async throws {
    let env = makeEnvironment()
    var profile = UserProfile.empty()
    let today = TrainingSchedule.weekday()
    profile.preferredTrainingDays = Weekday.allCases.filter { $0 != today }

    try await env.seedOnboardedProfile(profile)
    await env.bootstrap()

    XCTAssertTrue(env.isRestDay)
    XCTAssertNil(env.todayWorkout)
  }

  func testHandleAppBecameActiveRegeneratesStaleWorkoutAfterBootstrap() async throws {
    let calendar = Calendar.current
    let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
    let staleWorkout = FixtureBuilders.makeGeneratedWorkout(createdAt: yesterday)
    let freshWorkout = FixtureBuilders.makeGeneratedWorkout()
    let generator = FixedMockWorkoutGenerationService(workout: freshWorkout)
    var repos = TestRepositories.withCatalog()
    try await repos.workout.saveTodayWorkout(staleWorkout)

    let env = AppEnvironment.makeForTests(repos: repos, workoutGenerationService: generator)
    var profile = UserProfile.empty()
    profile.preferredTrainingDays = [TrainingSchedule.weekday(), .wednesday]
    try await env.seedOnboardedProfile(profile)
    await env.bootstrap()

    env.todayWorkout = staleWorkout
    try await repos.workout.saveTodayWorkout(staleWorkout)
    var state = env.programState
    state.todayCompletedOn = TrainingSchedule.startOfDay(yesterday)
    state.todayCompletedSessionId = UUID()
    env.programState = state
    try await repos.programState.saveState(state)

    await env.handleAppBecameActive()

    XCTAssertEqual(env.todayWorkout?.id, freshWorkout.id)
    XCTAssertNil(env.programState.todayCompletedOn)
    XCTAssertGreaterThan(env.calendarDayRevision, 0)
  }

  // MARK: - Start → log sets → complete

  func testStartLogSetsAndCompleteSessionFlow() async throws {
    let env = makeEnvironment()
    try await env.seedOnboardedProfile()
    await env.bootstrap()
    guard let workout = env.todayWorkout else {
      XCTFail("Expected today workout")
      return
    }

    guard var session = await env.resumeOrStartWorkout(from: workout) else {
      XCTFail("Expected active session")
      return
    }
    XCTAssertTrue(env.hasActiveWorkoutSession)

    logAllSets(in: &session)
    session.status = .completed
    session.completedAt = Date()

    try await env.saveWorkoutSessionImmediately(session)
    let notes = await env.applyWorkoutSessionCompletion(session)
    await env.refreshWorkoutAfterSession(session)

    XCTAssertFalse(session.exercises.allSatisfy(\.completedSets.isEmpty))
    XCTAssertTrue(env.isTodayWorkoutCompleted)
    XCTAssertFalse(env.hasActiveWorkoutSession)
    let minRecovery = env.recoveryStates.map(\.recoveryPercentage).min() ?? 100
    XCTAssertLessThan(minRecovery, 100)
  }

  func testCompletionPersistsSessionAndExerciseStats() async throws {
    let repos = TestRepositories.withCatalog()
    let env = AppEnvironment.makeForTests(repos: repos)
    try await env.seedOnboardedProfile()
    await env.bootstrap()

    guard let workout = env.todayWorkout,
          var session = await env.resumeOrStartWorkout(from: workout) else {
      XCTFail("Expected session")
      return
    }

    logAllSets(in: &session)
    session.status = .completed
    session.completedAt = Date()
    try await env.saveWorkoutSessionImmediately(session)
    _ = await env.applyWorkoutSessionCompletion(session)
    await env.refreshWorkoutAfterSession(session)

    let sessions = await env.fetchWorkoutSessions()
    XCTAssertTrue(sessions.contains { $0.id == session.id && $0.status == .completed })

    let stats = await env.fetchExerciseStats()
    XCTAssertFalse(stats.isEmpty)
  }

  func testCompletionAdvancesSplitRotationOnMatchingFocus() async throws {
    let env = makeEnvironment()
    var profile = UserProfile.empty()
    profile.preferredSplit = .pushPullLegs
    try await env.seedOnboardedProfile(profile)
    await env.bootstrap()

    let initialFocus = env.currentSplitFocus
    guard let workout = env.todayWorkout,
          var session = await env.resumeOrStartWorkout(from: workout) else {
      XCTFail("Expected session")
      return
    }
    session.splitDayFocus = initialFocus

    logAllSets(in: &session)
    session.status = .completed
    session.completedAt = Date()
    try await env.saveWorkoutSessionImmediately(session)
    _ = await env.applyWorkoutSessionCompletion(session)
    await env.refreshWorkoutAfterSession(session)

    if profile.preferredSplit == .pushPullLegs, initialFocus != nil {
      XCTAssertNotEqual(env.programState.splitDayIndex, 0)
    }
  }

  // MARK: - Regenerate

  func testRegenerateProducesFreshValidatedWorkout() async throws {
    let env = makeEnvironment()
    var profile = UserProfile.empty()
    profile.preferredTrainingDays = [TrainingSchedule.weekday(), .monday, .tuesday, .thursday, .friday]
    try await env.seedOnboardedProfile(profile)
    await env.bootstrap()

    guard let profile = env.userProfile else {
      XCTFail("Missing profile")
      return
    }
    let regenerated = await env.regenerateTodayWorkout(profile: profile)

    XCTAssertTrue(regenerated)
    XCTAssertNotNil(env.todayWorkout)
    XCTAssertTrue(env.lastValidation?.isValid ?? false)
    XCTAssertFalse(env.todayWorkout?.exercises.isEmpty ?? true)
  }

  func testRegenerateBlockedWhenTodayWorkoutCompleted() async throws {
    let env = makeEnvironment()
    try await env.seedOnboardedProfile()
    await env.bootstrap()

    var state = env.programState
    state.todayCompletedOn = TrainingSchedule.startOfDay(Date())
    state.todayCompletedSessionId = UUID()
    env.programState = state
    try await env.programStateRepository.saveState(state)

    guard let profile = env.userProfile else {
      XCTFail("Expected seeded profile")
      return
    }
    let regenerated = await env.regenerateTodayWorkout(profile: profile)
    XCTAssertFalse(regenerated)
  }

  func testRestartTodayWorkoutClearsCompletionMarkers() async throws {
    let env = makeEnvironment()
    try await env.seedOnboardedProfile()
    await env.bootstrap()

    var state = env.programState
    state.todayCompletedOn = TrainingSchedule.startOfDay(Date())
    state.todayCompletedSessionId = UUID()
    env.programState = state

    guard let profile = env.userProfile else {
      XCTFail("Expected seeded profile")
      return
    }
    let restarted = await env.restartTodayWorkout(profile: profile)
    XCTAssertTrue(restarted)
    XCTAssertFalse(env.isTodayWorkoutCompleted)
    XCTAssertNotNil(env.todayWorkout)
  }

  // MARK: - Rest day

  func testRestDayProfileIsDetectedAfterBootstrap() async throws {
    let env = makeEnvironment()
    var profile = UserProfile.empty()
    profile.preferredTrainingDays = [.monday]
    try await env.seedOnboardedProfile(profile)
    await env.bootstrap()

    if TrainingSchedule.isTrainingDay(profile: profile) {
      XCTAssertFalse(env.isRestDay)
    } else {
      XCTAssertTrue(env.isRestDay)
    }
  }

  func testRestDayCoachMessageMentionsRecovery() async throws {
    var profile = UserProfile.empty()
    let today = TrainingSchedule.weekday()
    profile.preferredTrainingDays = Weekday.allCases.filter { $0 != today }

    let message = CoachOfflineModify.restDayMessage(profile: profile)
    XCTAssertNotNil(message)
    XCTAssertTrue(message?.lowercased().contains("rest") == true)
  }

  // MARK: - Coach modify

  func testCoachSafeModificationAutoApplies() async throws {
    let env = makeEnvironment()
    try await env.seedOnboardedProfile()
    await env.bootstrap()

    guard let current = env.todayWorkout else {
      XCTFail("Missing workout")
      return
    }
    let allowedIds = (await env.fetchAllExercises()).map(\.id)
    let proposed = makeShorterCoachWorkout(from: current)
    let result = CoachAIResult(
      message: CoachMessage(
        id: UUID(),
        role: .assistant,
        content: "Trimmed accessories.",
        createdAt: Date(),
        intent: .modifyWorkout
      ),
      proposedWorkout: proposed,
      validation: WorkoutValidationResult(isValid: true, errors: [], warnings: [])
    )

    let applied = await env.tryAutoApplyCoachModification(result: result, allowedExerciseIds: allowedIds)
    XCTAssertTrue(applied)
    XCTAssertEqual(env.todayWorkout?.exercises.count, proposed.exercises.count)
    XCTAssertLessThan(
      env.todayWorkout?.exercises.first?.targetSets.count ?? 0,
      current.exercises.first?.targetSets.count ?? 0
    )
    XCTAssertEqual(env.coachWorkoutUpdateMessage, "Workout updated")
  }

  func testCoachModificationBlockedDuringActiveSession() async throws {
    let env = makeEnvironment()
    try await env.seedOnboardedProfile()
    await env.bootstrap()

    guard let workout = env.todayWorkout,
          let _ = await env.resumeOrStartWorkout(from: workout),
          let current = env.todayWorkout else {
      XCTFail("Expected active session")
      return
    }

    let proposed = makeShorterCoachWorkout(from: current)
    let result = CoachAIResult(
      message: CoachMessage(
        id: UUID(),
        role: .assistant,
        content: "Trim now",
        createdAt: Date(),
        intent: .modifyWorkout
      ),
      proposedWorkout: proposed,
      validation: nil
    )

    let applied = await env.tryAutoApplyCoachModification(
      result: result,
      allowedExerciseIds: (await env.fetchAllExercises()).map(\.id)
    )
    XCTAssertFalse(applied)
    let blocked = await env.blocksCoachWorkoutModification()
    XCTAssertTrue(blocked)
  }

  // MARK: - Settings equipment change

  func testEquipmentChangeRegeneratesWorkout() async throws {
    let env = makeEnvironment()
    try await env.seedOnboardedProfile()
    await env.bootstrap()
    let original = env.todayWorkout

    guard var profile = env.userProfile else {
      XCTFail("Expected seeded profile")
      return
    }
    profile.availableEquipment = [.dumbbell]
    let updated = await env.updateUserProfile(profile, refreshWorkout: true)

    XCTAssertTrue(updated)
    XCTAssertNotNil(env.todayWorkout)
    XCTAssertTrue(env.lastValidation?.isValid ?? false)
    if let original, let refreshed = env.todayWorkout {
      XCTAssertNotEqual(original.id, refreshed.id)
    }
  }

  func testEquipmentRestrictedProfileStillGeneratesValidWorkout() async throws {
    let env = makeEnvironment()
    var profile = UserProfile.empty()
    profile.availableEquipment = [.dumbbell]
    try await env.seedOnboardedProfile(profile)
    await env.bootstrap()

    XCTAssertNotNil(env.todayWorkout)
    let exercises = await env.fetchAllExercises()
    let map = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    for planned in env.todayWorkout?.exercises ?? [] {
      guard let exercise = map[planned.exerciseId] else { continue }
      XCTAssertTrue(EquipmentFilter.isExerciseAvailable(exercise, availableEquipment: [.dumbbell]))
    }
  }

  // MARK: - Deload

  func testDeloadStatsReducePrescribedIntensity() async throws {
    let repos = TestRepositories.withCatalog()
    let env = AppEnvironment.makeForTests(repos: repos)
    var profile = UserProfile.empty()
    profile.experienceLevel = .intermediate
    try await env.seedOnboardedProfile(profile)

    let deloadStats = UserExerciseStats(
      exerciseId: "bench_press",
      recentSets: [],
      preferredRepRangeMin: 5,
      preferredRepRangeMax: 8,
      deloadStartedAt: Date()
    )
    try await repos.exerciseStats.saveStats([deloadStats])

    guard let profile = env.userProfile else {
      XCTFail("Expected seeded profile")
      return
    }
    let input = await env.makeWorkoutGenerationInput(profile: profile, splitDayFocus: .push)
    let workout = try await env.workoutGenerationService.generate(input: input)

    if let bench = workout.exercises.first(where: { $0.exerciseId == "bench_press" }) {
      for set in bench.targetSets where !set.isWarmup {
        XCTAssertLessThanOrEqual(set.rpeTarget ?? 10, GenerationConstants.Session.deloadRpeTarget)
      }
    }
  }

  func testDeloadWeekFlagExpiresAfterSevenDays() async throws {
    let now = Date()
    var stats = UserExerciseStats(
      exerciseId: "squat",
      preferredRepRangeMin: 5,
      preferredRepRangeMax: 8,
      deloadStartedAt: now.addingTimeInterval(-8 * 24 * 3600)
    )
    XCTAssertFalse(stats.isInDeloadWeek(at: now))
  }

  // MARK: - Relaunch

  func testRelaunchBootstrapRestoresPersistedState() async throws {
    try await PersistenceTestHelpers.withIsolatedPersistenceOnMainActor {
      let repos = TestRepositories.withCatalog()
      let env = AppEnvironment.makeForTests(repos: repos)
      try await env.seedOnboardedProfile()
      await env.bootstrap()

      guard let workout = env.todayWorkout else {
        XCTFail("Expected workout")
        return
      }
      try await env.workoutRepository.saveTodayWorkout(workout)

      let relaunched = AppEnvironment.makeForTests(repos: repos)
      await relaunched.bootstrap()

      XCTAssertTrue(relaunched.hasCompletedOnboarding)
      XCTAssertEqual(relaunched.todayWorkout?.id, workout.id)
      XCTAssertFalse(relaunched.recoveryStates.isEmpty)
    }
  }

  func testRelaunchAppliesRecoveryDecay() async throws {
    let env = makeEnvironment()
    try await env.seedOnboardedProfile()
    await env.bootstrap()

    var states = env.recoveryStates
    states[0] = MuscleRecoveryState(
      muscleGroup: states[0].muscleGroup,
      recoveryPercentage: 45,
      lastTrainedAt: Date().addingTimeInterval(-48 * 3600),
      accumulatedFatigue: 5
    )
    env.recoveryStates = states
    try await env.recoveryRepository.saveRecoveryStates(states)

    var programState = env.programState
    programState.lastRecoveryDecayAppliedAt = Date().addingTimeInterval(-24 * 3600)
    env.programState = programState
    try await env.programStateRepository.saveState(programState)

    await env.applyRecoveryDecay()
    let chest = env.recoveryStates.first { $0.muscleGroup == .chest }!
    XCTAssertGreaterThan(chest.recoveryPercentage, 45)
  }

  // MARK: - Catalog sweep

  func testCatalogSweepRepairsOrphanWorkoutReferences() async throws {
    let repos = TestRepositories.withCatalog()
    let env = AppEnvironment.makeForTests(repos: repos)
    try await env.seedOnboardedProfile()

    let staleWorkout = GeneratedWorkout(
      id: UUID(),
      title: "Stale",
      estimatedDurationMinutes: 45,
      focus: [.chest],
      exercises: [
        PlannedExercise(exerciseId: "bench_press", orderIndex: 0, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
        PlannedExercise(exerciseId: "removed_move", orderIndex: 1, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
        PlannedExercise(exerciseId: "squat", orderIndex: 2, targetSets: [PlannedSet(targetRepsMin: 5, targetRepsMax: 8)]),
        PlannedExercise(exerciseId: "deadlift", orderIndex: 3, targetSets: [PlannedSet(targetRepsMin: 5, targetRepsMax: 8)])
      ],
      rationale: "",
      safetyNotes: [],
      generatedBy: .rulesEngine,
      createdAt: Date()
    )
    env.todayWorkout = staleWorkout
    try await repos.workout.saveTodayWorkout(staleWorkout)

    try await repos.exerciseStats.saveStats([
      UserExerciseStats(
        exerciseId: "removed_move",
        recentSets: [],
        preferredRepRangeMin: 8,
        preferredRepRangeMax: 12
      )
    ])

    await env.repairPersistedCatalogReferences()

    if let repaired = env.todayWorkout {
      XCTAssertFalse(repaired.exercises.contains { $0.exerciseId == "removed_move" })
    } else {
      XCTAssertNil(env.todayWorkout)
    }

    let stats = await env.fetchExerciseStats()
    XCTAssertTrue(stats.first { $0.exerciseId == "removed_move" }?.isOrphaned == true)
  }

  func testCatalogSweepClearsWorkoutWhenTooFewExercisesRemain() async throws {
    let repos = TestRepositories.withCatalog()
    let env = AppEnvironment.makeForTests(repos: repos)
    try await env.seedOnboardedProfile()

    let staleWorkout = GeneratedWorkout(
      id: UUID(),
      title: "Mostly Orphaned",
      estimatedDurationMinutes: 45,
      focus: [.chest],
      exercises: [
        PlannedExercise(exerciseId: "orphan_a", orderIndex: 0, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
        PlannedExercise(exerciseId: "orphan_b", orderIndex: 1, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
        PlannedExercise(exerciseId: "orphan_c", orderIndex: 2, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)])
      ],
      rationale: "",
      safetyNotes: [],
      generatedBy: .rulesEngine,
      createdAt: Date()
    )
    env.todayWorkout = staleWorkout

    await env.repairPersistedCatalogReferences()
    XCTAssertNil(env.todayWorkout)
  }

  // MARK: - Parity E2E gaps

  func testRegression_excludedExerciseNeverAppearsInGeneratedWorkout() async throws {
    let env = makeEnvironment()
    try await env.seedOnboardedProfile()
    try await env.exerciseRepository.updatePreference(id: "bench_press", preference: .excluded)

    guard let profile = env.userProfile else {
      XCTFail("Missing profile")
      return
    }
    let input = await env.makeWorkoutGenerationInput(profile: profile, splitDayFocus: .push)
    let workout = try await env.workoutGenerationService.generate(input: input)

    XCTAssertFalse(workout.exercises.contains { $0.exerciseId == "bench_press" })
    XCTAssertTrue(env.workoutGenerationService.validate(workout: workout, input: input).isValid)
  }

  func testRegression_rpeCompletionUpdatesSuggestedNextWeight() async throws {
    let env = makeEnvironment()
    try await env.seedOnboardedProfile()
    await env.bootstrap()

    guard let workout = env.todayWorkout,
          let session = await env.resumeOrStartWorkout(from: workout),
          let exercise = workout.exercises.first else {
      XCTFail("Expected active session")
      return
    }

    var updated = session
    let planned = updated.exercises[0].plannedSets.first { !$0.isWarmup } ?? updated.exercises[0].plannedSets[0]
    updated.exercises[0].completedSets = [
      CompletedSet(
        setIndex: 0,
        weightKg: planned.targetWeightKg ?? 60,
        reps: planned.targetRepsMax,
        rpe: 9
      )
    ]
    updated.status = .completed
    updated.completedAt = Date()

    _ = await env.applyWorkoutSessionCompletion(updated)
    let stats = await env.fetchExerciseStats()
    let benchStats = stats.first { $0.exerciseId == exercise.exerciseId }
    XCTAssertNotNil(benchStats?.suggestedNextWeightKg)
  }

  func testRegression_maxEffortUpdateStatsRespectsWeightCeilings() {
    let maxEffortSet = CompletedSet(setIndex: 2, weightKg: 100, reps: 8)
    let planned = [
      PlannedSet(targetRepsMin: 8, targetRepsMax: 10, isWarmup: true),
      PlannedSet(targetRepsMin: 5, targetRepsMax: 8),
      PlannedSet(targetRepsMin: 3, targetRepsMax: 5, isMaxEffort: true)
    ]
    let updated = ProgressiveOverload.updateStats(
      existing: UserExerciseStats(
        exerciseId: "bench_press",
        lastWeightKg: 90,
        preferredRepRangeMin: 5,
        preferredRepRangeMax: 8
      ),
      exerciseId: "bench_press",
      completedSets: [
        CompletedSet(setIndex: 0, weightKg: 60, reps: 8, isWarmup: true),
        CompletedSet(setIndex: 1, weightKg: 80, reps: 8),
        maxEffortSet
      ],
      plannedSets: planned,
      equipment: [.dumbbell],
      weightCeilings: [.dumbbell: 22]
    )
    XCTAssertEqual(updated.suggestedNextWeightKg, 22)
  }

  func testRegression_customExerciseCanAppearInGeneratedWorkout() async throws {
    let customId = "custom_integration_press"
    let custom = Exercise(
      id: customId,
      name: "Integration Press",
      slug: "integration-press",
      primaryMuscles: [.chest],
      secondaryMuscles: [.triceps],
      equipment: [.dumbbell, .bench],
      movementPattern: .horizontalPush,
      difficulty: .beginner,
      forceType: .push,
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
    let exercises = [
      custom,
      makeStubExercise(id: "support_row", muscles: [.back], pattern: .horizontalPull, equipment: [.dumbbell]),
      makeStubExercise(id: "support_press", muscles: [.shoulders], pattern: .verticalPush, equipment: [.dumbbell]),
      makeStubExercise(id: "support_fly", muscles: [.chest], pattern: .isolation, equipment: [.dumbbell])
    ]
    let repos = TestRepositories.empty(exercises: exercises)
    let env = AppEnvironment.makeForTests(repos: repos)
    var profile = UserProfile.empty()
    profile.availableEquipment = [.dumbbell, .bench]
    try await env.seedOnboardedProfile(profile)

    let input = await env.makeWorkoutGenerationInput(profile: profile, splitDayFocus: .push)
    let workout = try await env.workoutGenerationService.generate(input: input)
    XCTAssertTrue(workout.exercises.contains { $0.exerciseId == customId })
  }

  func testRegression_highExerciseVariabilityChangesSelectionOrder() async throws {
    let exercises = await makeEnvironment().fetchAllExercises()
    let candidates = exercises.filter { $0.primaryMuscles.contains(.chest) && $0.movementPattern == .horizontalPush }.prefix(4)
    XCTAssertGreaterThanOrEqual(candidates.count, 2)

    let scored: [(Exercise, Double)] = Array(candidates.enumerated()).map { index, exercise in
      (exercise, Double(100 - index * 5))
    }
    let consistent = WorkoutGenerationAlgorithms.rankScored(
      scored,
      variability: .consistent,
      avoidIds: []
    )
    let varied = WorkoutGenerationAlgorithms.rankScored(
      scored,
      variability: .varied,
      avoidIds: [scored[0].0.id],
      variationSeed: 7
    )

    XCTAssertEqual(consistent.map(\.0.id), scored.map(\.0.id).sorted { lhs, rhs in
      let l = scored.first { $0.0.id == lhs }!.1
      let r = scored.first { $0.0.id == rhs }!.1
      return l > r
    })
    XCTAssertNotEqual(varied.map(\.0.id), consistent.map(\.0.id))
  }

  func testCloudDTORoundTripPreservesGroupIdAndCooldown() {
    let groupId = UUID()
    let exercise = WorkoutExercise(
      exerciseId: "bench_press",
      orderIndex: 0,
      plannedSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)],
      groupId: groupId
    )
    let exerciseRow = WorkoutExerciseRow(exercise: exercise, sessionId: UUID())
    XCTAssertEqual(exerciseRow.groupId, groupId)

    let cooldownSet = CompletedSet(setIndex: 1, reps: 15, isCooldown: true)
    let setRow = CompletedSetRow(set: cooldownSet, workoutExerciseId: UUID())
    XCTAssertTrue(setRow.isCooldown)
    XCTAssertEqual(setRow.reps, 15)
  }

  // MARK: - Helpers

  private func makeEnvironment() -> AppEnvironment {
    AppEnvironment.makeForTests(repos: TestRepositories.withCatalog())
  }

  private func logAllSets(in session: inout WorkoutSession) {
    let now = Date()
    for exerciseIndex in session.exercises.indices {
      for setIndex in session.exercises[exerciseIndex].plannedSets.indices {
        let planned = session.exercises[exerciseIndex].plannedSets[setIndex]
        session.exercises[exerciseIndex].completedSets.append(
          CompletedSet(
            setIndex: setIndex,
            weightKg: planned.targetWeightKg,
            reps: planned.targetRepsMax,
            completedAt: now,
            isWarmup: planned.isWarmup
          )
        )
      }
    }
  }

  private func makeShorterCoachWorkout(from current: GeneratedWorkout) -> GeneratedWorkout {
    let trimmedExercises = current.exercises.map { exercise -> PlannedExercise in
      var copy = exercise
      if copy.targetSets.count > 1 {
        copy.targetSets = Array(copy.targetSets.dropLast())
      }
      return copy
    }
    return GeneratedWorkout(
      id: UUID(),
      title: current.title,
      estimatedDurationMinutes: max(20, current.estimatedDurationMinutes - 10),
      focus: current.focus,
      exercises: trimmedExercises,
      rationale: current.rationale,
      safetyNotes: current.safetyNotes,
      generatedBy: .aiAssisted,
      createdAt: Date()
    )
  }
}
