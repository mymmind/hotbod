import XCTest
@testable import HotBod

@MainActor
final class AppEnvironmentDayRolloverTests: XCTestCase {
    func testRegression_revalidateOnResumeRegeneratesStaleWorkoutFromYesterday() async throws {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let staleWorkout = FixtureBuilders.makeGeneratedWorkout(createdAt: yesterday)
        let freshWorkout = FixtureBuilders.makeGeneratedWorkout()
        let generator = FixedMockWorkoutGenerationService(workout: freshWorkout)
        let repos = TestRepositories.empty()
        try await repos.workout.saveTodayWorkout(staleWorkout)

        let env = AppEnvironment.makeForTests(repos: repos, workoutGenerationService: generator)
        var profile = UserProfile.empty()
        profile.reminderTrainingDays = [TrainingSchedule.weekday(), .wednesday]
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

    func testRegression_revalidateAutoGeneratesOnNonPreferredDay() async {
        let workout = FixtureBuilders.makeGeneratedWorkout()
        let generator = FixedMockWorkoutGenerationService(workout: workout)
        let env = AppEnvironment.makeForTests(workoutGenerationService: generator)
        let today = TrainingSchedule.weekday()
        var profile = UserProfile.empty()
        profile.reminderTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(2))
        env.userProfile = profile
        env.hasCompletedOnboarding = true
        env.recoveryStates = RecoveryCalculator.defaultStates()

        await env.revalidateTodayPlanForCurrentDay()

        XCTAssertEqual(env.todayWorkout?.id, workout.id)
        XCTAssertTrue(env.isRestDay)
    }

    func testRegression_revalidateRegeneratesStalePlanOnNonPreferredDay() async throws {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let staleWorkout = FixtureBuilders.makeGeneratedWorkout(createdAt: yesterday)
        let freshWorkout = FixtureBuilders.makeGeneratedWorkout()
        let generator = FixedMockWorkoutGenerationService(workout: freshWorkout)
        let repos = TestRepositories.empty()
        try await repos.workout.saveTodayWorkout(staleWorkout)

        let env = AppEnvironment.makeForTests(repos: repos, workoutGenerationService: generator)
        let today = TrainingSchedule.weekday()
        var profile = UserProfile.empty()
        profile.reminderTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(2))
        try await env.seedOnboardedProfile(profile)
        env.todayWorkout = staleWorkout
        env.recoveryStates = RecoveryCalculator.defaultStates()

        await env.revalidateTodayPlanForCurrentDay()

        XCTAssertTrue(env.isRestDay)
        XCTAssertEqual(
            env.todayWorkout?.id,
            freshWorkout.id,
            "stale non-preferred-day plan must regenerate, not clear-to-empty"
        )
        XCTAssertNotEqual(env.todayWorkout?.id, staleWorkout.id)
    }

    func testRegression_revalidateDoesNotClearFreshPlanOnNonPreferredDay() async throws {
        let fresh = FixtureBuilders.makeGeneratedWorkout(createdAt: Date())
        let repos = TestRepositories.empty()
        try await repos.workout.saveTodayWorkout(fresh)
        let env = AppEnvironment.makeForTests(repos: repos)
        let today = TrainingSchedule.weekday()
        var profile = UserProfile.empty()
        profile.reminderTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(2))
        env.userProfile = profile
        env.hasCompletedOnboarding = true
        env.todayWorkout = fresh

        await env.revalidateTodayPlanForCurrentDay()

        XCTAssertEqual(env.todayWorkout?.id, fresh.id)
    }
}
