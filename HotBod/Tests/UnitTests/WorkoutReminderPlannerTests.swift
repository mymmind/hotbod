import XCTest
@testable import HotBod

final class WorkoutReminderPlannerTests: XCTestCase {
    func testSlotsDisabledReturnsEmpty() {
        let slots = WorkoutReminderPlanner.slots(
            days: [.monday, .wednesday],
            timeOfDay: .morning,
            enabled: false
        )
        XCTAssertTrue(slots.isEmpty)
    }

    func testSlotsUsesTimePreferenceHourAndDedupesDays() {
        let slots = WorkoutReminderPlanner.slots(
            days: [.friday, .monday, .friday],
            timeOfDay: .evening,
            enabled: true
        )
        XCTAssertEqual(slots.map(\.weekday), [.monday, .friday])
        XCTAssertTrue(slots.allSatisfy { $0.hour == 17 && $0.minute == 0 })
        XCTAssertEqual(slots.first?.identifier, "hotbod.workout.2.17.0")
    }

    func testRegression_reminderTitleIncludesFocusHint() {
        XCTAssertEqual(WorkoutReminderPlanner.title(for: "Push"), "Push session")
        XCTAssertEqual(WorkoutReminderPlanner.title(for: nil), "Training day")
    }

    func testRegression_alreadyTrainedTodayDefersSameDayReminderToNextWeek() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        // Monday 19 Oct 2026, 08:00 — before the 09:00 flexible reminder.
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 8))
        )
        XCTAssertEqual(calendar.component(.weekday, from: now), Weekday.monday.rawValue)

        let occurrences = WorkoutReminderPlanner.occurrences(
            days: [.monday, .wednesday],
            timeOfDay: .flexible,
            enabled: true,
            alreadyTrainedToday: true,
            now: now,
            calendar: calendar
        )

        let monday = try XCTUnwrap(occurrences.first { $0.slot.weekday == .monday })
        XCTAssertFalse(monday.repeatsWeekly)
        let nextMonday = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 9))
        )
        XCTAssertEqual(monday.fireOn, nextMonday)

        let wednesday = try XCTUnwrap(occurrences.first { $0.slot.weekday == .wednesday })
        XCTAssertTrue(wednesday.repeatsWeekly)
        XCTAssertNil(wednesday.fireOn)
    }

    func testNotYetTrainedKeepsWeeklyRepeats() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 8))!

        let occurrences = WorkoutReminderPlanner.occurrences(
            days: [.monday],
            timeOfDay: .flexible,
            enabled: true,
            alreadyTrainedToday: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(occurrences.count, 1)
        XCTAssertTrue(occurrences[0].repeatsWeekly)
        XCTAssertNil(occurrences[0].fireOn)
    }
}

@MainActor
final class WorkoutReminderRescheduleTests: XCTestCase {
    func testRegression_completedWorkoutSuppressesTodaysReminder() async throws {
        let recorder = RecordingWorkoutReminderScheduler()
        let env = AppEnvironment.makeForTests(workoutReminderScheduler: recorder)
        try await env.seedOnboardedProfile()

        await env.rescheduleWorkoutReminders()
        XCTAssertEqual(recorder.alreadyTrainedFlags, [false])

        let session = FixtureBuilders.makeWorkoutSession(status: .completed)
        await env.refreshWorkoutAfterSession(session)

        XCTAssertTrue(env.isTodayWorkoutCompleted)
        XCTAssertEqual(recorder.alreadyTrainedFlags, [false, true])
    }
}

final class AdaptiveSplitFocusTests: XCTestCase {
    func testAdaptiveFocusPrefersFresherRegion() {
        var states = RecoveryCalculator.defaultStates()
        for index in states.indices {
            if [.chest, .back, .shoulders, .biceps, .triceps].contains(states[index].muscleGroup) {
                states[index].recoveryPercentage = 90
            } else if [.quads, .hamstrings, .glutes, .calves].contains(states[index].muscleGroup) {
                states[index].recoveryPercentage = 40
            }
        }
        XCTAssertEqual(TrainingSchedule.adaptiveFocus(recoveryStates: states), .upper)
    }

    func testResolveGenerationFocusUsesAdaptiveForAdaptiveSplit() {
        var states = RecoveryCalculator.defaultStates()
        for index in states.indices where [.quads, .hamstrings, .glutes, .calves].contains(states[index].muscleGroup) {
            states[index].recoveryPercentage = 95
        }
        for index in states.indices where [.chest, .back, .shoulders, .biceps, .triceps].contains(states[index].muscleGroup) {
            states[index].recoveryPercentage = 30
        }
        let focus = TrainingSchedule.resolveGenerationFocus(
            state: TrainingProgramState(),
            split: .adaptive,
            recoveryStates: states
        )
        XCTAssertEqual(focus, .lower)
    }
}

final class UserProfileReminderDaysCodingTests: XCTestCase {
    func testDecodesLegacyPreferredTrainingDaysKey() throws {
        var profile = UserProfile.empty()
        profile.reminderTrainingDays = [.tuesday, .thursday]
        let data = try JSONEncoder().encode(profile)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return XCTFail("Expected JSON object")
        }
        object.removeValue(forKey: "reminderTrainingDays")
        object["preferredTrainingDays"] = [3, 5] // Tue, Thu raw values
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: legacyData)
        XCTAssertEqual(decoded.reminderTrainingDays, [.tuesday, .thursday])
        XCTAssertEqual(decoded.trainingDaysPerWeek, 2)
    }

    func testTrainingDaysPerWeekIsDerivedNotIndependent() {
        var profile = UserProfile.empty()
        profile.reminderTrainingDays = [.monday, .wednesday, .friday]
        XCTAssertEqual(profile.trainingDaysPerWeek, 3)
    }
}
