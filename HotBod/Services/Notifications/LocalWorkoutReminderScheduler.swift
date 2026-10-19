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

    func reschedule(profile: UserProfile, focusHint: String?, alreadyTrainedToday: Bool) async {
        await cancelAll()
        if alreadyTrainedToday {
            await removeDeliveredWorkoutReminders()
        }
        guard profile.workoutRemindersEnabled else { return }
        let authorized = await requestAuthorizationIfNeeded()
        guard authorized else { return }

        let occurrences = WorkoutReminderPlanner.occurrences(
            days: profile.reminderTrainingDays,
            timeOfDay: profile.timeOfDayPreference,
            enabled: true,
            alreadyTrainedToday: alreadyTrainedToday,
            now: Date(),
            calendar: .current
        )
        let contentTitle = WorkoutReminderPlanner.title(for: focusHint)
        let contentBody = WorkoutReminderPlanner.body()

        for occurrence in occurrences {
            let content = UNMutableNotificationContent()
            content.title = contentTitle
            content.body = contentBody
            content.sound = .default

            guard let trigger = notificationTrigger(for: occurrence) else { continue }
            let request = UNNotificationRequest(
                identifier: occurrence.slot.identifier,
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

    private func removeDeliveredWorkoutReminders() async {
        let delivered = await center.deliveredNotifications()
        let ids = delivered.map(\.request.identifier).filter { $0.hasPrefix("hotbod.workout.") }
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    private func notificationTrigger(for occurrence: WorkoutReminderOccurrence) -> UNCalendarNotificationTrigger? {
        if occurrence.repeatsWeekly {
            var date = DateComponents()
            date.weekday = occurrence.slot.weekday.rawValue
            date.hour = occurrence.slot.hour
            date.minute = occurrence.slot.minute
            return UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        }
        guard let fireOn = occurrence.fireOn else { return nil }
        var date = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireOn)
        date.second = 0
        return UNCalendarNotificationTrigger(dateMatching: date, repeats: false)
    }
}
