import XCTest
@testable import HotBod

final class RecoveryCalculatorTests: XCTestCase {
    func testDefaultRecoveryIsHigh() {
        let states = RecoveryCalculator.defaultStates()
        XCTAssertEqual(states.count, MuscleGroup.allCases.count)
        XCTAssertTrue(states.allSatisfy { $0.recoveryPercentage == 100 })
    }

    func testDuplicateMuscleEntriesKeepMinimumRecovery() {
        let duplicates = [
            MuscleRecoveryState(muscleGroup: .chest, recoveryPercentage: 80, lastTrainedAt: nil, accumulatedFatigue: 0),
            MuscleRecoveryState(muscleGroup: .chest, recoveryPercentage: 35, lastTrainedAt: nil, accumulatedFatigue: 0),
            MuscleRecoveryState(muscleGroup: .back, recoveryPercentage: 90, lastTrainedAt: nil, accumulatedFatigue: 0)
        ]

        let normalized = RecoveryCalculator.normalizeStates(duplicates)
        let chest = normalized.first { $0.muscleGroup == .chest }!

        XCTAssertEqual(normalized.filter { $0.muscleGroup == .chest }.count, 1)
        XCTAssertEqual(chest.recoveryPercentage, 35)
    }

    func testRecoveryMapDoesNotTrapOnDuplicates() {
        let duplicates = [
            MuscleRecoveryState(muscleGroup: .quads, recoveryPercentage: 60, lastTrainedAt: nil, accumulatedFatigue: 0),
            MuscleRecoveryState(muscleGroup: .quads, recoveryPercentage: 25, lastTrainedAt: nil, accumulatedFatigue: 0)
        ]

        let map = RecoveryCalculator.recoveryMap(from: duplicates)
        XCTAssertEqual(map[.quads], 25)
    }

    func testNormalizeBackfillsMissingMuscleAt100() {
        let partial = [
            MuscleRecoveryState(muscleGroup: .chest, recoveryPercentage: 55, lastTrainedAt: nil, accumulatedFatigue: 0)
        ]

        let normalized = RecoveryCalculator.normalizeStates(partial)
        XCTAssertEqual(normalized.count, MuscleGroup.allCases.count)
        XCTAssertEqual(normalized.first { $0.muscleGroup == .calves }?.recoveryPercentage, 100)
    }

    func testUnknownMuscleDefaultsToFullyRecovered() {
        let map = GenerationConstants.Recovery.recovery(for: .shoulders, in: [:])
        XCTAssertEqual(map, 100)
    }

    func testWorkoutFatigueReducesRecovery() {
        let exercise = Exercise(
            id: "squat", name: "Squat", slug: "squat",
            primaryMuscles: [.quads], secondaryMuscles: [.glutes],
            equipment: [.barbell], movementPattern: .squat, difficulty: .intermediate,
            forceType: .push, mechanics: .compound,
            instructions: [], formCues: [], commonMistakes: [], contraindications: [],
            substitutions: [], progressions: [], regressions: [], demoVideos: [], imageUrl: nil, tags: []
        )
        let states = RecoveryCalculator.defaultStates()
        let completed = [(exercise, [CompletedSet(setIndex: 0, weightKg: 100, reps: 5)])]
        let updated = RecoveryCalculator.applyWorkoutFatigue(states: states, exercises: [exercise], completedSets: completed)
        let quads = updated.first { $0.muscleGroup == .quads }!
        XCTAssertLessThan(quads.recoveryPercentage, 100)
    }
}

final class RecoveryDecayTests: XCTestCase {
    func testDecayIncreasesRecoveryOverTime() {
        var states = RecoveryCalculator.defaultStates()
        states[0] = MuscleRecoveryState(
            muscleGroup: .chest,
            recoveryPercentage: 40,
            lastTrainedAt: Date().addingTimeInterval(-48 * 3600),
            accumulatedFatigue: 10
        )
        let decay = RecoveryCalculator.decayRecovery(states: states, experienceLevel: .intermediate)
        let chest = decay.states.first { $0.muscleGroup == .chest }!
        XCTAssertGreaterThan(chest.recoveryPercentage, 40)
    }
}
