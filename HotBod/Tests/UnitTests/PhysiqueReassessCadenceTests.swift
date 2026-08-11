import XCTest
@testable import HotBod

final class PhysiqueReassessCadenceTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    func testDueDateIsSixWeeksAfterCreatedAt() {
        let created = Date(timeIntervalSince1970: 1_700_000_000) // fixed
        let due = PhysiqueReassessCadence.dueDate(from: created, calendar: calendar)
        let weeks = calendar.dateComponents([.weekOfYear], from: created, to: due).weekOfYear
        XCTAssertEqual(weeks, 6)
        XCTAssertEqual(PhysiqueReassessCadence.intervalWeeks, 6)
    }

    func testIsDueFalseBeforeInterval() {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let now = calendar.date(byAdding: .day, value: 20, to: created)!
        XCTAssertFalse(PhysiqueReassessCadence.isDue(
            assessmentCreatedAt: created, now: now, calendar: calendar
        ))
    }

    func testIsDueTrueAtOrAfterInterval() {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let due = PhysiqueReassessCadence.dueDate(from: created, calendar: calendar)
        XCTAssertTrue(PhysiqueReassessCadence.isDue(
            assessmentCreatedAt: created, now: due, calendar: calendar
        ))
        XCTAssertTrue(PhysiqueReassessCadence.isDue(
            assessmentCreatedAt: created,
            now: due.addingTimeInterval(3600),
            calendar: calendar
        ))
    }

    func testNextFireNilWhenAlreadyPastDue() {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let due = PhysiqueReassessCadence.dueDate(from: created, calendar: calendar)
        let comps = PhysiqueReassessCadence.nextFireDateComponents(
            from: created,
            timeOfDay: .morning,
            now: due.addingTimeInterval(1),
            calendar: calendar
        )
        XCTAssertNil(comps)
    }

    func testNextFireUsesReminderHourOnDueCalendarDay() {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let due = PhysiqueReassessCadence.dueDate(from: created, calendar: calendar)
        let now = calendar.date(byAdding: .day, value: -1, to: due)!
        let comps = PhysiqueReassessCadence.nextFireDateComponents(
            from: created,
            timeOfDay: .evening,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(comps?.hour, TimeOfDayPreference.evening.reminderHour)
        XCTAssertEqual(comps?.minute, 0)
        XCTAssertEqual(comps?.day, calendar.component(.day, from: due))
        XCTAssertEqual(comps?.month, calendar.component(.month, from: due))
        XCTAssertEqual(comps?.year, calendar.component(.year, from: due))
    }

    func testNextFireFallsBackToDueInstantWhenMorningAlreadyPassedButNotYetDue() {
        // due evening; now is afternoon same calendar day as due → morning fire missed
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let due = PhysiqueReassessCadence.dueDate(from: created, calendar: calendar)
        var morningComps = calendar.dateComponents([.year, .month, .day], from: due)
        morningComps.hour = TimeOfDayPreference.morning.reminderHour
        morningComps.minute = 0
        let morningFire = calendar.date(from: morningComps)!
        // Pick a now after morning fire but before due (if due is later that day)
        // If due itself is before/at morning (unlikely with +6 weeks preserving time-of-day),
        // construct now = due - 1 hour when that is after morning fire.
        let now = max(morningFire.addingTimeInterval(3600), due.addingTimeInterval(-3600))
        guard now < due else {
            // Skip pathological timezone/edge; still assert nil-vs-components contract below
            return
        }
        let comps = PhysiqueReassessCadence.nextFireDateComponents(
            from: created,
            timeOfDay: .morning,
            now: now,
            calendar: calendar
        )
        XCTAssertNotNil(comps)
        let fire = calendar.date(from: comps!)
        XCTAssertEqual(fire!.timeIntervalSince1970, due.timeIntervalSince1970, accuracy: 1)
    }

    func testNotificationRoutingMatchesPrefix() {
        XCTAssertTrue(PhysiqueNotificationRouting.shouldOpenPhysique(
            identifier: PhysiqueReassessCadence.notificationIdentifier
        ))
        XCTAssertTrue(PhysiqueNotificationRouting.shouldOpenPhysique(
            identifier: "hotbod.physique.reassess.extra"
        ))
        XCTAssertFalse(PhysiqueNotificationRouting.shouldOpenPhysique(
            identifier: "hotbod.workout.2.7.0"
        ))
    }

    func testPlannerCopyAndIdentifier() {
        XCTAssertEqual(PhysiqueReassessReminderPlanner.identifier, "hotbod.physique.reassess")
        XCTAssertEqual(PhysiqueReassessReminderPlanner.title(), "Time to reassess")
        XCTAssertEqual(
            PhysiqueReassessReminderPlanner.body(),
            "Capture updated photos and refresh your Physique focus."
        )
    }
}
