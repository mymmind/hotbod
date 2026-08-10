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
