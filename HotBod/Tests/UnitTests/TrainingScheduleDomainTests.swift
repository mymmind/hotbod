import XCTest
@testable import HotBod

final class TrainingScheduleTests: XCTestCase {
    func testRestDayRespectsPreferredTrainingDays() {
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = [.monday, .wednesday, .friday]
        XCTAssertTrue(TrainingSchedule.isTrainingDay(profile: profile, date: dateFor(weekday: .monday)))
        XCTAssertFalse(TrainingSchedule.isTrainingDay(profile: profile, date: dateFor(weekday: .tuesday)))
    }

    func testEmptyPreferredDaysTreatsEveryDayAsTrainingDay() {
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = []
        for day in Weekday.allCases {
            XCTAssertTrue(
                TrainingSchedule.isTrainingDay(profile: profile, date: dateFor(weekday: day)),
                "\(day) should be a training day when preferred days are empty"
            )
        }
    }

    func testSplitRotationAdvances() {
        var state = TrainingProgramState()
        TrainingSchedule.advanceRotation(state: &state, split: .upperLower)
        XCTAssertEqual(state.splitDayIndex, 1)
        XCTAssertEqual(TrainingSchedule.currentSplitFocus(state: state, split: .upperLower), .lower)
    }

    func testUpperLowerSequence() {
        let sequence = TrainingSchedule.splitSequence(for: .upperLower)
        XCTAssertEqual(sequence, [.upper, .lower])
    }

    func testNextTrainingDateSkipsRestDays() {
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = [.monday, .wednesday, .friday]
        let monday = dateFor(weekday: .monday)
        let next = TrainingSchedule.nextTrainingDate(profile: profile, from: monday)
        XCTAssertNotNil(next)
        XCTAssertEqual(TrainingSchedule.weekday(for: next!), .wednesday)
    }

    func testTodayWorkoutCompletedOnlyOnSameDay() {
        var state = TrainingProgramState()
        state.todayCompletedOn = TrainingSchedule.startOfDay(Date())
        XCTAssertTrue(TrainingSchedule.isTodayWorkoutCompleted(state: state))

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        state.todayCompletedOn = TrainingSchedule.startOfDay(yesterday)
        XCTAssertFalse(TrainingSchedule.isTodayWorkoutCompleted(state: state))
    }

    func testUpcomingWorkoutValidOnScheduledTrainingDay() {
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = [.monday, .wednesday, .friday]
        var state = TrainingProgramState()
        let today = dateFor(weekday: .wednesday)
        state.upcomingWorkout = GeneratedWorkout(
            id: UUID(),
            title: "Lower Strength",
            estimatedDurationMinutes: 45,
            focus: [.quads],
            exercises: [],
            rationale: "Test",
            safetyNotes: [],
            generatedBy: .rulesEngine,
            createdAt: today
        )
        state.upcomingWorkoutFor = TrainingSchedule.startOfDay(today)
        XCTAssertTrue(TrainingSchedule.isUpcomingWorkoutValid(state: state, profile: profile, date: today))
    }

    func testAdaptiveSplitHasNoRotationFocus() {
        let state = TrainingProgramState()
        XCTAssertEqual(TrainingSchedule.splitSequence(for: .adaptive), [])
        XCTAssertNil(TrainingSchedule.currentSplitFocus(state: state, split: .adaptive))
    }

    func testAdaptiveSplitDoesNotAdvanceRotation() {
        var state = TrainingProgramState()
        TrainingSchedule.advanceRotation(state: &state, split: .adaptive)
        XCTAssertEqual(state.splitDayIndex, 0)
    }

    func testSelectableSplitsExcludePlaceholders() {
        XCTAssertFalse(TrainingSplit.selectableSplits.contains(.bodyPart))
        XCTAssertFalse(TrainingSplit.selectableSplits.contains(.custom))
        XCTAssertTrue(TrainingSplit.selectableSplits.contains(.adaptive))
    }

    func testBodyPartSplitUsesBodybuildingRotationSequence() {
        XCTAssertEqual(TrainingSchedule.splitSequence(for: .bodyPart), [.push, .pull, .legs])
    }

    func testCustomSplitDefaultsToSafeFullBodyFocus() {
        XCTAssertEqual(TrainingSchedule.splitSequence(for: .custom), [.fullBody])
    }

    func testClearStaleCompletionRemovesPriorDayMarker() {
        var state = TrainingProgramState()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        state.todayCompletedOn = TrainingSchedule.startOfDay(yesterday)
        state.todayCompletedSessionId = UUID()
        TrainingSchedule.clearStaleCompletion(state: &state)
        XCTAssertNil(state.todayCompletedOn)
        XCTAssertNil(state.todayCompletedSessionId)
    }

    private func dateFor(weekday: Weekday) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = Weekday.sunday.rawValue
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = weekday.rawValue
        components.hour = 12
        return calendar.date(from: components) ?? Date()
    }
}
