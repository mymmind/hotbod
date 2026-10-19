import Foundation

struct WorkoutReminderSlot: Equatable, Sendable {
    let weekday: Weekday
    let hour: Int
    let minute: Int

    var identifier: String {
        "hotbod.workout.\(weekday.rawValue).\(hour).\(minute)"
    }
}

struct WorkoutReminderOccurrence: Equatable, Sendable {
    let slot: WorkoutReminderSlot
    /// Weekly repeat. False when this weekday is today and the user already trained:
    /// that pending fire is replaced with a one-shot next week.
    let repeatsWeekly: Bool
    let fireOn: Date?
}

enum WorkoutReminderPlanner {
    static func slots(
        days: [Weekday],
        timeOfDay: TimeOfDayPreference,
        enabled: Bool
    ) -> [WorkoutReminderSlot] {
        occurrences(
            days: days,
            timeOfDay: timeOfDay,
            enabled: enabled,
            alreadyTrainedToday: false,
            now: Date(),
            calendar: .current
        ).map(\.slot)
    }

    static func occurrences(
        days: [Weekday],
        timeOfDay: TimeOfDayPreference,
        enabled: Bool,
        alreadyTrainedToday: Bool,
        now: Date,
        calendar: Calendar
    ) -> [WorkoutReminderOccurrence] {
        guard enabled else { return [] }
        let hour = timeOfDay.reminderHour
        let today = Weekday(rawValue: calendar.component(.weekday, from: now))
        let uniqueDays = Weekday.allCases.filter { days.contains($0) }
        return uniqueDays.map { weekday in
            let slot = WorkoutReminderSlot(weekday: weekday, hour: hour, minute: 0)
            let deferToday = alreadyTrainedToday && weekday == today
            if deferToday,
               let fireOn = nextFireAfterToday(
                weekday: weekday,
                hour: hour,
                minute: 0,
                now: now,
                calendar: calendar
               ) {
                return WorkoutReminderOccurrence(slot: slot, repeatsWeekly: false, fireOn: fireOn)
            }
            return WorkoutReminderOccurrence(slot: slot, repeatsWeekly: true, fireOn: nil)
        }
    }

    /// Next matching weekday/hour strictly after today, so a deferred reminder cannot fire later the same day.
    private static func nextFireAfterToday(
        weekday: Weekday,
        hour: Int,
        minute: Int,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        guard let startOfNextDay = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        ) else { return nil }
        var components = DateComponents()
        components.weekday = weekday.rawValue
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.nextDate(
            after: startOfNextDay.addingTimeInterval(-1),
            matching: components,
            matchingPolicy: .nextTime
        )
    }

    static func title(for focusHint: String?) -> String {
        if let focusHint, !focusHint.isEmpty {
            return "\(focusHint) session"
        }
        return "Training day"
    }

    static func body() -> String {
        "Your usual training day — open HotBod when you're ready."
    }
}

protocol WorkoutReminderScheduling: AnyObject, Sendable {
    func requestAuthorizationIfNeeded() async -> Bool
    func reschedule(profile: UserProfile, focusHint: String?, alreadyTrainedToday: Bool) async
    func cancelAll() async
}

final class NoOpWorkoutReminderScheduler: WorkoutReminderScheduling, @unchecked Sendable {
    func requestAuthorizationIfNeeded() async -> Bool { false }
    func reschedule(profile: UserProfile, focusHint: String?, alreadyTrainedToday: Bool) async {}
    func cancelAll() async {}
}
