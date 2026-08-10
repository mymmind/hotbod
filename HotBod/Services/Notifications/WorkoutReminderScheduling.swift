import Foundation

struct WorkoutReminderSlot: Equatable, Sendable {
    let weekday: Weekday
    let hour: Int
    let minute: Int

    var identifier: String {
        "hotbod.workout.\(weekday.rawValue).\(hour).\(minute)"
    }
}

enum WorkoutReminderPlanner {
    static func slots(
        days: [Weekday],
        timeOfDay: TimeOfDayPreference,
        enabled: Bool
    ) -> [WorkoutReminderSlot] {
        guard enabled else { return [] }
        let hour = timeOfDay.reminderHour
        let uniqueDays = Weekday.allCases.filter { days.contains($0) }
        return uniqueDays.map { WorkoutReminderSlot(weekday: $0, hour: hour, minute: 0) }
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
    func reschedule(profile: UserProfile, focusHint: String?) async
    func cancelAll() async
}

final class NoOpWorkoutReminderScheduler: WorkoutReminderScheduling, @unchecked Sendable {
    func requestAuthorizationIfNeeded() async -> Bool { false }
    func reschedule(profile: UserProfile, focusHint: String?) async {}
    func cancelAll() async {}
}
