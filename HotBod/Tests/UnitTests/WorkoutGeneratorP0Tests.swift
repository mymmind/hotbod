import XCTest
@testable import HotBod

// UI exemption: the RIR sheet and the two settings rows are user-facing.
// Their programming effects are covered by testRegression_skippedEffort and
// testRegression_untrustedHistoricEffort. No new UI test is added in this release.
// The Skip control keeps accessibility identifier workout.rir.skip.

final class WorkoutGeneratorP0Tests: XCTestCase {
    func testRegression_doubleProgression() {
        let stored = SessionLoadPlanner.Input(
            suggestedNextWeightKg: 67.5,
            lastWeightKg: 65,
            sessionMode: .standard,
            isInDeloadWeek: false,
            returningFromBreak: false,
            equipment: [.barbell],
            ceilings: [:],
            fallbackWeightKg: 20
        )
        XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(stored), 67.5)
        XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(stored), 67.5)

        for trend in [TrendDirection.stable, .increasing, .decreasing] {
            _ = trend
            XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(stored), 67.5)
        }

        var deload = stored
        deload.isInDeloadWeek = true
        XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(deload), 60)
        XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(deload), 60)

        var recovery = stored
        recovery.sessionMode = .recovery
        let recoveryOnce = SessionLoadPlanner.plannedWeightKg(recovery)
        XCTAssertEqual(recoveryOnce, SessionLoadPlanner.plannedWeightKg(recovery))
        XCTAssertEqual(
            recoveryOnce,
            GenerationConstants.Weight.roundToAvailable(67.5 * 0.7, equipment: [.barbell])
        )

        var reentry = stored
        reentry.returningFromBreak = true
        let reentryOnce = SessionLoadPlanner.plannedWeightKg(reentry)
        XCTAssertEqual(reentryOnce, SessionLoadPlanner.plannedWeightKg(reentry))
        XCTAssertEqual(
            reentryOnce,
            GenerationConstants.Weight.roundToAvailable(
                67.5 * GenerationConstants.Deload.reEntryWeightMultiplier,
                equipment: [.barbell]
            )
        )

        var loggedOnly = stored
        loggedOnly.suggestedNextWeightKg = nil
        XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(loggedOnly), 65)

        var cold = stored
        cold.suggestedNextWeightKg = nil
        cold.lastWeightKg = nil
        XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(cold), 20)
    }

    func testRegression_doubleProgressionGeneratedWorkoutMatchesPlanner() async throws {
        let catalog = try await LocalExerciseRepository().fetchAll()
        let stats = catalog.map { exercise in
            var stat = UserExerciseStats(
                exerciseId: exercise.id,
                lastWeightKg: 65,
                suggestedNextWeightKg: 67.5,
                preferredRepRangeMin: 8,
                preferredRepRangeMax: 12
            )
            stat.volumeTrend = .increasing
            return stat
        }
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
            muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 100.0) }),
            exerciseStats: stats,
            userPreferences: WorkoutPreferences(exerciseVariability: .consistent),
            readiness: ReadinessInput(soreness: .none),
            splitDayFocus: .push
        )
        let service = RulesWorkoutGenerationService()
        let first = try await service.generate(input: input)
        let second = try await service.generate(input: input)
        let map = ExerciseCatalog.indexedById(catalog)

        func assertMatchesPlanner(_ workout: GeneratedWorkout) {
            for planned in workout.exercises {
                guard let exercise = map[planned.exerciseId],
                      let stat = stats.first(where: { $0.exerciseId == exercise.id }) else { continue }
                let expected = SessionLoadPlanner.plannedWeightKg(
                    SessionLoadPlanner.Input(
                        suggestedNextWeightKg: stat.suggestedNextWeightKg,
                        lastWeightKg: stat.lastWeightKg,
                        sessionMode: workout.sessionMode,
                        isInDeloadWeek: stat.isInDeloadWeek,
                        returningFromBreak: stat.returningFromBreak,
                        equipment: exercise.equipment,
                        ceilings: profile.maxAvailableWeightKg,
                        fallbackWeightKg: 0
                    )
                )
                for set in planned.targetSets where !set.isWarmup && !set.isCooldown {
                    guard let weight = set.targetWeightKg else { continue }
                    XCTAssertEqual(weight, expected, accuracy: 0.01, "\(exercise.id)")
                }
            }
        }

        assertMatchesPlanner(first)
        assertMatchesPlanner(second)
        let firstWeights = first.exercises.flatMap { $0.targetSets.compactMap(\.targetWeightKg) }
        let secondWeights = second.exercises.flatMap { $0.targetSets.compactMap(\.targetWeightKg) }
        XCTAssertEqual(firstWeights, secondWeights)

        let bench = try XCTUnwrap(map["bench_press"])
        let benchStats = try XCTUnwrap(stats.first { $0.exerciseId == "bench_press" })
        let manual = SessionExercisePlanner.makeWorkoutExercise(
            exercise: bench,
            orderIndex: 0,
            experience: .intermediate,
            goal: .buildMuscle,
            bodyWeightKg: 80,
            stats: benchStats,
            sessionMode: .standard
        )
        let manualWeight = try XCTUnwrap(manual.plannedSets.first { !$0.isWarmup }?.targetWeightKg)
        let expected = SessionLoadPlanner.plannedWeightKg(
            SessionLoadPlanner.Input(
                suggestedNextWeightKg: 67.5,
                lastWeightKg: 65,
                sessionMode: .standard,
                isInDeloadWeek: false,
                returningFromBreak: false,
                equipment: bench.equipment,
                ceilings: [:],
                fallbackWeightKg: 0
            )
        )
        XCTAssertEqual(manualWeight, expected, accuracy: 0.01)
    }

    func testRegression_skippedEffort() throws {
        var skipped = CompletedSet(setIndex: 0, weightKg: 65, reps: 10, rpe: 10, rir: 0, isFailure: true)
        EffortFeedbackMapping.markSkipped(&skipped)
        XCTAssertEqual(skipped.effortFeedbackStatus, .skipped)
        XCTAssertNil(skipped.rpe)
        XCTAssertNil(skipped.rir)
        XCTAssertFalse(skipped.isFailure)

        var explicit = CompletedSet(setIndex: 0, weightKg: 65, reps: 10)
        EffortFeedbackMapping.markExplicit(&explicit, rir: 0)
        XCTAssertEqual(explicit.effortFeedbackStatus, .explicit)
        XCTAssertEqual(explicit.rir, 0)
        XCTAssertEqual(explicit.rpe, 10)
        XCTAssertTrue(explicit.isFailure)

        var easy = explicit
        EffortFeedbackMapping.markExplicit(&easy, rir: 2)
        XCTAssertFalse(easy.isFailure)

        let planned = [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]
        let skippedSets = [CompletedSet(setIndex: 0, weightKg: 100, reps: 10, effortFeedbackStatus: .skipped)]
        let silentSets = [CompletedSet(setIndex: 0, weightKg: 100, reps: 10)]
        let skippedStats = ProgressiveOverload.updateStats(
            existing: nil, exerciseId: "bench_press", completedSets: skippedSets,
            plannedSets: planned, trustHistoricEffortFeedback: false
        )
        let silentStats = ProgressiveOverload.updateStats(
            existing: nil, exerciseId: "bench_press", completedSets: silentSets,
            plannedSets: planned, trustHistoricEffortFeedback: false
        )
        XCTAssertEqual(skippedStats.suggestedNextWeightKg, silentStats.suggestedNextWeightKg)
        XCTAssertEqual(skippedStats.suggestedNextWeightKg, 102.5)

        let hardSets = [
            CompletedSet(setIndex: 0, weightKg: 100, reps: 10, rpe: 10, rir: 0, effortFeedbackStatus: .explicit)
        ]
        let hardStats = ProgressiveOverload.updateStats(
            existing: nil, exerciseId: "bench_press", completedSets: hardSets,
            plannedSets: planned, trustHistoricEffortFeedback: false
        )
        XCTAssertEqual(try XCTUnwrap(hardStats.suggestedNextWeightKg), 100, accuracy: 0.1)

        var historic = UserExerciseStats(
            exerciseId: "bench_press", lastWeightKg: 100, lastReps: 10,
            suggestedNextWeightKg: 100, preferredRepRangeMin: 8, preferredRepRangeMax: 10
        )
        historic.recentSets = [
            CompletedSet(setIndex: 0, weightKg: 100, reps: 10, rir: 0, effortFeedbackStatus: .unknown)
        ]
        historic.deloadStartedAt = Date()
        let trusted = EffortFeedbackMapping.trustedEffectiveRPE(
            rpe: nil, rir: 0, status: .unknown, trustHistoric: true
        )
        let ignored = EffortFeedbackMapping.trustedEffectiveRPE(
            rpe: nil, rir: 0, status: .unknown, trustHistoric: false
        )
        XCTAssertEqual(trusted, 10)
        XCTAssertNil(ignored)

        var untrusted = historic
        ProgressiveOverload.reapplyEffortTrust(stats: &untrusted, trustHistoric: false)
        XCTAssertEqual(untrusted.lastWeightKg, 100)
        XCTAssertEqual(untrusted.lastReps, 10)
        XCTAssertNotNil(untrusted.deloadStartedAt)
        XCTAssertEqual(untrusted.suggestedNextWeightKg, 102.5)

        // Legacy JSON: encode a set, strip effortFeedbackStatus, decode without that key.
        let encoded = try JSONEncoder().encode(CompletedSet(setIndex: 0, reps: 8))
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            XCTFail("Expected a JSON object for CompletedSet")
            return
        }
        object.removeValue(forKey: "effortFeedbackStatus")
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(CompletedSet.self, from: stripped)
        XCTAssertEqual(decoded.effortFeedbackStatus, .unknown)
    }

    func testRegression_skippedEffortHighEffortDeloadTrust() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        func makeStats(status: EffortFeedbackStatus) -> UserExerciseStats {
            var stats = UserExerciseStats(
                exerciseId: "bench_press",
                recentSets: (0..<3).map { index in
                    CompletedSet(
                        setIndex: index,
                        weightKg: 100,
                        reps: 10,
                        rpe: 10,
                        rir: 0,
                        completedAt: now,
                        effortFeedbackStatus: status
                    )
                },
                preferredRepRangeMin: 8,
                preferredRepRangeMax: 10
            )
            stats.weeklyVolume = []
            stats.consecutiveHighVolumeWeeks = 0
            return stats
        }

        let explicitUntrusted = DeloadDetector.analyzeDeloadNeed(
            stats: makeStats(status: .explicit),
            volumeHistory: [],
            consecutiveWeeks: 0,
            now: now,
            trustHistoricEffortFeedback: false
        )
        XCTAssertTrue(explicitUntrusted.isDeloadRecommended)

        let unknownUntrusted = DeloadDetector.analyzeDeloadNeed(
            stats: makeStats(status: .unknown),
            volumeHistory: [],
            consecutiveWeeks: 0,
            now: now,
            trustHistoricEffortFeedback: false
        )
        XCTAssertFalse(unknownUntrusted.isDeloadRecommended)

        let unknownTrusted = DeloadDetector.analyzeDeloadNeed(
            stats: makeStats(status: .unknown),
            volumeHistory: [],
            consecutiveWeeks: 0,
            now: now,
            trustHistoricEffortFeedback: true
        )
        XCTAssertTrue(unknownTrusted.isDeloadRecommended)
    }

    func testRegression_skippedEffortProfileDefaults() throws {
        // Legacy JSON: encode a profile, strip the two new keys, decode without them.
        let encoded = try JSONEncoder().encode(UserProfile.empty())
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            XCTFail("Expected a JSON object for UserProfile")
            return
        }
        object.removeValue(forKey: "promptForEffortFeedback")
        object.removeValue(forKey: "trustHistoricEffortFeedback")
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: stripped)
        XCTAssertTrue(decoded.promptForEffortFeedback)
        XCTAssertTrue(decoded.trustHistoricEffortFeedback)

        let original = UserProfile.empty()
        var draft = original
        draft.trustHistoricEffortFeedback = false
        XCTAssertTrue(SettingsDraftEditing.shouldRefreshWorkout(draft: draft, comparedTo: original))
        draft = original
        draft.promptForEffortFeedback = false
        XCTAssertFalse(SettingsDraftEditing.shouldRefreshWorkout(draft: draft, comparedTo: original))
    }

    func testRegression_inlineRPEStaysExplicit() {
        var withRPE = CompletedSet(setIndex: 0, weightKg: 65, reps: 10, rpe: 8)
        EffortFeedbackMapping.applyCommitEffort(&withRPE, loggedRPE: 8)
        XCTAssertEqual(withRPE.rpe, 8)
        XCTAssertEqual(withRPE.effortFeedbackStatus, .explicit)

        var withoutRPE = CompletedSet(setIndex: 0, weightKg: 65, reps: 10)
        EffortFeedbackMapping.applyCommitEffort(&withoutRPE, loggedRPE: nil)
        XCTAssertEqual(withoutRPE.effortFeedbackStatus, .skipped)
        XCTAssertNil(withoutRPE.rpe)

        var skipped = CompletedSet(setIndex: 0, weightKg: 65, reps: 10, effortFeedbackStatus: .skipped)
        EffortFeedbackMapping.recordEditedRPE(&skipped, rpe: 9)
        XCTAssertEqual(skipped.effortFeedbackStatus, .explicit)
        XCTAssertEqual(skipped.rpe, 9)
    }

    func testRegression_durationBudget() {
        let squatA = makeTestExercise(id: "squat_a", primaryMuscles: [.quads], pattern: .squat, mechanics: .compound, equipment: [.barbell])
        let squatB = makeTestExercise(id: "squat_b", primaryMuscles: [.quads], pattern: .squat, mechanics: .compound, equipment: [.barbell])
        let curl = makeTestExercise(id: "leg_curl", primaryMuscles: [.hamstrings], pattern: .isolation, mechanics: .isolation, equipment: [.machine])
        let core = makeTestExercise(id: "plank", primaryMuscles: [.abs], pattern: .isolation, mechanics: .isolation, equipment: [.bodyweight])
        let map = [squatA.id: squatA, squatB.id: squatB, curl.id: curl, core.id: core]

        func workingSets(_ count: Int, warmup: Bool) -> [PlannedSet] {
            var sets: [PlannedSet] = []
            if warmup {
                sets.append(PlannedSet(targetRepsMin: 5, targetRepsMax: 8, isWarmup: true))
            }
            sets.append(contentsOf: (0..<count).map { _ in
                PlannedSet(targetRepsMin: 8, targetRepsMax: 12)
            })
            return sets
        }

        var full: [PlannedExercise] = [
            PlannedExercise(exerciseId: squatA.id, orderIndex: 0, targetSets: workingSets(6, warmup: true), restSeconds: 120),
            PlannedExercise(exerciseId: squatB.id, orderIndex: 1, targetSets: workingSets(6, warmup: true), restSeconds: 120),
            PlannedExercise(exerciseId: curl.id, orderIndex: 2, targetSets: workingSets(5, warmup: true), restSeconds: 75)
        ]
        let beforeOptional = WorkoutGenerationAlgorithms.estimateDurationMinutes(planned: full)
        XCTAssertGreaterThanOrEqual(beforeOptional, 45)

        full.append(PlannedExercise(
            exerciseId: core.id, orderIndex: 3,
            targetSets: (0..<4).map { _ in PlannedSet(targetRepsMin: 10, targetRepsMax: 15) },
            restSeconds: 30
        ))
        full[0].targetSets.append(PlannedSet(targetRepsMin: 10, targetRepsMax: 15, isCooldown: true))

        let result = SessionDurationBudget.apply(
            SessionDurationBudget.Input(
                planned: full,
                scores: [squatA.id: 10, squatB.id: 10, curl.id: 4, core.id: 1],
                targetMuscles: [.quads, .hamstrings],
                exerciseMap: map,
                targetDurationMinutes: 45,
                coreFinisherExerciseId: core.id,
                conditioningExerciseId: nil
            )
        )
        XCTAssertFalse(result.planned.contains(where: { $0.exerciseId == core.id }))
        XCTAssertFalse(result.planned.contains(where: { $0.targetSets.contains(where: \.isCooldown) }))
        let firstWarmups = result.planned[0].targetSets.filter(\.isWarmup).count
        XCTAssertGreaterThan(firstWarmups, 0)
        if result.planned.count > 1 {
            XCTAssertFalse(result.planned[1].targetSets.contains(where: \.isWarmup))
        }
        let minutes = WorkoutGenerationAlgorithms.estimateDurationMinutes(planned: result.planned)
        let suffix = SessionDurationBudget.rationaleSuffix(
            removedCooldown: result.removedCooldown,
            removedConditioning: result.removedConditioning,
            removedCore: result.removedCore,
            removedExtraWarmups: result.removedExtraWarmups,
            removedAccessory: result.removedAccessory,
            targetMinutes: 45,
            estimatedMinutes: minutes
        )
        if minutes > 45 {
            XCTAssertTrue(suffix?.contains("Priority work exceeds the 45 min target.") == true)
        } else {
            XCTAssertLessThanOrEqual(minutes, 45)
        }
        XCTAssertTrue(suffix?.contains("core finisher") == true)

        let again = SessionDurationBudget.apply(
            SessionDurationBudget.Input(
                planned: result.planned,
                scores: [squatA.id: 10, squatB.id: 10, curl.id: 4],
                targetMuscles: [.quads, .hamstrings],
                exerciseMap: map,
                targetDurationMinutes: 45,
                coreFinisherExerciseId: nil,
                conditioningExerciseId: nil
            )
        )
        XCTAssertEqual(again.planned.map(\.exerciseId), result.planned.map(\.exerciseId))
        XCTAssertFalse(again.removedCooldown)
        XCTAssertFalse(again.removedCore)

        var oneSet = [PlannedExercise(
            exerciseId: squatA.id, orderIndex: 0,
            targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 12, isWarmup: true)],
            restSeconds: 30
        )]
        let withPad = WorkoutGenerationAlgorithms.estimateDurationMinutes(planned: oneSet)
        oneSet[0].targetSets.removeAll(where: \.isWarmup)
        let without = WorkoutGenerationAlgorithms.estimateDurationMinutes(planned: oneSet)
        XCTAssertLessThan(without, withPad)

        XCTAssertEqual(
            SessionDurationBudget.rationaleSuffix(
                removedCooldown: true, removedConditioning: false, removedCore: false,
                removedExtraWarmups: false, removedAccessory: false,
                targetMinutes: 45, estimatedMinutes: 40
            ),
            "Adjusted to fit 45 min by removing cooldown."
        )
        XCTAssertEqual(
            SessionDurationBudget.rationaleSuffix(
                removedCooldown: true, removedConditioning: true, removedCore: true,
                removedExtraWarmups: false, removedAccessory: false,
                targetMinutes: 45, estimatedMinutes: 40
            ),
            "Adjusted to fit 45 min by removing cooldown, conditioning, and core finisher."
        )
        XCTAssertEqual(
            SessionDurationBudget.rationaleSuffix(
                removedCooldown: false, removedConditioning: false, removedCore: false,
                removedExtraWarmups: false, removedAccessory: false,
                targetMinutes: 45, estimatedMinutes: 52
            ),
            "Estimated 52 min. Priority work exceeds the 45 min target."
        )
    }
}
