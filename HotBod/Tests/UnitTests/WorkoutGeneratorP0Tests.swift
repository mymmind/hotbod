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
}
