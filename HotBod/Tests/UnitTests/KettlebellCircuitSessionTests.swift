import XCTest
@testable import HotBod

@MainActor
final class KettlebellCircuitSessionTests: XCTestCase {
    func testRegression_kettlebellCircuitFinishDoesNotMarkTodayComplete() async throws {
        var repos = TestRepositories.withCatalog()
        var profile = UserProfile.empty()
        profile.availableEquipment = Equipment.allCases
        profile.preferredSplit = .upperLower
        try await repos.userProfile.saveProfile(profile)
        try await repos.userProfile.setOnboardingComplete(true)

        var state = TrainingProgramState()
        state.splitDayIndex = 0
        try await repos.programState.saveState(state)

        let env = AppEnvironment.makeForTests(repos: repos)
        await env.bootstrap()
        let gymWorkoutId = env.todayWorkout?.id

        let started = await env.startKettlebellCircuit(profile: profile)
        let session = try XCTUnwrap(started)
        XCTAssertEqual(session.sessionMode, .kettlebellCircuit)
        XCTAssertNil(session.splitDayFocus)
        // Circuit start must not clobber a standard gym today plan from bootstrap.
        XCTAssertEqual(env.todayWorkout?.id, gymWorkoutId)
        XCTAssertNotEqual(env.todayWorkout?.sessionMode, .kettlebellCircuit)

        let beforeIndex = env.programState.splitDayIndex
        _ = await env.completeWorkoutSession(session)

        XCTAssertFalse(env.isTodayWorkoutCompleted)
        XCTAssertNil(env.programState.todayCompletedOn)
        XCTAssertNil(env.programState.todayCompletedSessionId)
        XCTAssertEqual(env.programState.splitDayIndex, beforeIndex)
        XCTAssertNil(env.programState.activeSessionId)
    }

    func testGenerateKettlebellCircuitLeavesStandardTodayWorkoutIntact() async throws {
        var repos = TestRepositories.withCatalog()
        var profile = UserProfile.empty()
        profile.availableEquipment = Equipment.allCases
        try await repos.userProfile.saveProfile(profile)
        try await repos.userProfile.setOnboardingComplete(true)

        let gym = FixtureBuilders.makeGeneratedWorkout()
        try await repos.workout.saveTodayWorkout(gym)

        let env = AppEnvironment.makeForTests(repos: repos)
        await env.bootstrap()
        XCTAssertEqual(env.todayWorkout?.id, gym.id)

        let generated = await env.generateKettlebellCircuit(profile: profile)
        let circuit = try XCTUnwrap(generated)
        XCTAssertEqual(circuit.sessionMode, .kettlebellCircuit)
        XCTAssertEqual(env.todayWorkout?.id, gym.id)
    }
}
