import Foundation
import UserNotifications

/// Schedules a one-shot local notification for the next physique reassess due date.
final class LocalPhysiqueReassessReminderScheduler: PhysiqueReassessReminderScheduling, @unchecked Sendable {
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

    func reschedule(profile: UserProfile, assessmentCreatedAt: Date?) async {
        await cancelAll()
        guard profile.workoutRemindersEnabled, let createdAt = assessmentCreatedAt else { return }
        guard let comps = PhysiqueReassessCadence.nextFireDateComponents(
            from: createdAt,
            timeOfDay: profile.timeOfDayPreference
        ) else { return }
        let authorized = await requestAuthorizationIfNeeded()
        guard authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = PhysiqueReassessReminderPlanner.title()
        content.body = PhysiqueReassessReminderPlanner.body()
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: PhysiqueReassessReminderPlanner.identifier,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter {
            $0.hasPrefix(PhysiqueReassessCadence.notificationIdentifier)
        }
        var toRemove = Set(ids)
        toRemove.insert(PhysiqueReassessReminderPlanner.identifier)
        center.removePendingNotificationRequests(withIdentifiers: Array(toRemove))
    }
}
