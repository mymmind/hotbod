import Foundation
import UserNotifications

/// Schedules repeating local notifications on the user's reminder training days.
final class LocalWorkoutReminderScheduler: WorkoutReminderScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    func reschedule(profile: UserProfile, focusHint: String?) async {
        await cancelAll()
        guard profile.workoutRemindersEnabled else { return }
        let authorized = await requestAuthorizationIfNeeded()
        guard authorized else { return }

        let slots = WorkoutReminderPlanner.slots(
            days: profile.reminderTrainingDays,
            timeOfDay: profile.timeOfDayPreference,
            enabled: true
        )
        let contentTitle = WorkoutReminderPlanner.title(for: focusHint)
        let contentBody = WorkoutReminderPlanner.body()

        for slot in slots {
            let content = UNMutableNotificationContent()
            content.title = contentTitle
            content.body = contentBody
            content.sound = .default

            var date = DateComponents()
            date.weekday = slot.weekday.rawValue
            date.hour = slot.hour
            date.minute = slot.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(
                identifier: slot.identifier,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("hotbod.workout.") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
