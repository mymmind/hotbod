import XCTest
@testable import HotBod

final class RecoveryCalculatorTests: XCTestCase {
    func testDefaultRecoveryIsHigh() {
        let states = RecoveryCalculator.defaultStates()
        XCTAssertEqual(states.count, MuscleGroup.allCases.count)
        XCTAssertTrue(states.allSatisfy { $0.recoveryPercentage >= 80 })
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
        XCTAssertLessThan(quads.recoveryPercentage, 85)
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
        let updated = RecoveryCalculator.decayRecovery(states: states, experienceLevel: .intermediate)
        let chest = updated.first { $0.muscleGroup == .chest }!
        XCTAssertGreaterThan(chest.recoveryPercentage, 40)
    }
}
