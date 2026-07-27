import XCTest
@testable import HotBod

final class EffortPolicyTests: XCTestCase {
    func testHypertrophyWorkingTargetsStandardRPE() {
        let context = EffortPolicy.context(
            EffortPolicy.SessionSignals(
                goal: .buildMuscle,
                experience: .intermediate,
                mechanics: .compound,
                sessionMode: .standard,
                isDeload: false,
                returningFromBreak: false,
                sleepScore: 80
            )
        )
        XCTAssertEqual(context, .hypertrophyWorking)
        XCTAssertEqual(EffortPolicy.targetRPE(for: context), GenerationConstants.Session.standardRpeTarget)
    }

    func testStrengthCompoundLeavesMoreRIR() {
        let context = EffortPolicy.context(
            EffortPolicy.SessionSignals(
                goal: .gainStrength,
                experience: .advanced,
                mechanics: .compound,
                sessionMode: .standard,
                isDeload: false,
                returningFromBreak: false,
                sleepScore: nil
            )
        )
        XCTAssertEqual(context, .strengthCompound)
        XCTAssertEqual(EffortPolicy.targetRPE(for: context), 7.5)
    }

    func testIsolationFinisherAllowsHigherRPE() {
        let context = EffortPolicy.context(
            EffortPolicy.SessionSignals(
                goal: .buildMuscle,
                experience: .intermediate,
                mechanics: .isolation,
                sessionMode: .standard,
                isDeload: false,
                returningFromBreak: false,
                sleepScore: nil
            )
        )
        XCTAssertEqual(EffortPolicy.targetRPE(for: context), 9.0)
    }

    func testProgressionHypertrophyDoubleProgression() {
        XCTAssertEqual(
            ProgressionPolicy.action(
                goal: .buildMuscle,
                hitTopOfRepRange: true,
                missedMinimumReps: false,
                stalledSessions: 0
            ),
            .increaseLoad
        )
        XCTAssertEqual(
            ProgressionPolicy.action(
                goal: .buildMuscle,
                hitTopOfRepRange: false,
                missedMinimumReps: false,
                stalledSessions: 0
            ),
            .holdLoadIncreaseReps
        )
    }

    func testProgressionStrengthLoadFirst() {
        XCTAssertEqual(
            ProgressionPolicy.action(
                goal: .gainStrength,
                hitTopOfRepRange: false,
                missedMinimumReps: false,
                stalledSessions: 0
            ),
            .hold
        )
    }

    func testStallPrefersVariation() {
        XCTAssertEqual(
            ProgressionPolicy.action(
                goal: .buildMuscle,
                hitTopOfRepRange: true,
                missedMinimumReps: false,
                stalledSessions: ProgressionPolicy.stallSessionThreshold
            ),
            .preferVariation
        )
    }

    func testStalledSessionCountIgnoresIntraSessionSetDrops() {
        let now = Date()
        // Same session: set volume drops within the workout must not count as stalls.
        let sameSession: [CompletedSet] = (0..<4).map { index in
            CompletedSet(
                setIndex: index,
                weightKg: 100,
                reps: 10 - index,
                completedAt: now.addingTimeInterval(Double(index) * 120)
            )
        }
        let stats = UserExerciseStats(
            exerciseId: "bench",
            recentSets: sameSession,
            preferredRepRangeMin: 8,
            preferredRepRangeMax: 10
        )
        XCTAssertEqual(ProgressionPolicy.stalledSessionCount(stats: stats), 0)
    }

    func testStalledSessionCountTracksAcrossSessions() {
        let now = Date()
        let day: TimeInterval = 24 * 3600
        var sets: [CompletedSet] = []
        // Four sessions of identical volume → three consecutive non-improving steps.
        for session in 0..<4 {
            let base = now.addingTimeInterval(-Double(3 - session) * day)
            sets.append(CompletedSet(setIndex: 0, weightKg: 100, reps: 8, completedAt: base))
            sets.append(CompletedSet(setIndex: 1, weightKg: 100, reps: 8, completedAt: base.addingTimeInterval(90)))
        }
        let stats = UserExerciseStats(
            exerciseId: "bench",
            recentSets: sets,
            preferredRepRangeMin: 8,
            preferredRepRangeMax: 10
        )
        XCTAssertGreaterThanOrEqual(
            ProgressionPolicy.stalledSessionCount(stats: stats),
            ProgressionPolicy.stallSessionThreshold
        )
    }

    func testAvoidExerciseIdsMergesStalledFlags() {
        let stalled = UserExerciseStats(
            exerciseId: "bench",
            preferredRepRangeMin: 8,
            preferredRepRangeMax: 10,
            preferVariation: true
        )
        let fresh = UserExerciseStats(
            exerciseId: "squat",
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )
        XCTAssertEqual(
            ProgressionPolicy.avoidExerciseIds(from: [stalled, fresh], additional: ["curl"]),
            ["bench", "curl"]
        )
    }

    func testScheduledDeloadAfterSustainedHighVolume() {
        var stats = UserExerciseStats(exerciseId: "bench", preferredRepRangeMin: 8, preferredRepRangeMax: 10)
        stats.consecutiveHighVolumeWeeks = GenerationConstants.Deload.scheduledAfterHighVolumeWeeks
        let analysis = DeloadDetector.analyzeDeloadNeed(
            stats: stats,
            volumeHistory: [40, 42, 41],
            consecutiveWeeks: stats.consecutiveHighVolumeWeeks
        )
        XCTAssertTrue(analysis.isDeloadRecommended)
        XCTAssertTrue(analysis.reason.contains("Scheduled volume wave"))
    }
}
