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
        XCTAssertEqual(session.kettlebellCircuitScheme, profile.kettlebellCircuitScheme.clamped)
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

    func testRegression_circuitSessionKeepsSchemeSnapshotAfterProfileEdit() async throws {
        var repos = TestRepositories.withCatalog()
        var profile = UserProfile.empty()
        profile.availableEquipment = Equipment.allCases
        profile.kettlebellCircuitScheme = KettlebellCircuitScheme(
            exerciseCount: 3,
            reps: 4,
            rounds: 6,
            transitionRestSeconds: 20,
            roundRestSeconds: 90
        )
        try await repos.userProfile.saveProfile(profile)
        try await repos.userProfile.setOnboardingComplete(true)

        let env = AppEnvironment.makeForTests(repos: repos)
        await env.bootstrap()

        let started = await env.startKettlebellCircuit(profile: profile)
        let session = try XCTUnwrap(started)
        XCTAssertEqual(session.kettlebellCircuitScheme?.roundRestSeconds, 90)

        var updated = profile
        updated.kettlebellCircuitScheme = .default
        _ = await env.updateUserProfile(updated, refreshWorkout: false)
        XCTAssertEqual(env.userProfile?.kettlebellCircuitScheme, .default)

        let fetched = await env.fetchActiveWorkoutSession()
        let live = try XCTUnwrap(fetched)
        XCTAssertEqual(live.kettlebellCircuitScheme?.transitionRestSeconds, 20)
        XCTAssertEqual(live.kettlebellCircuitScheme?.roundRestSeconds, 90)
    }
}
