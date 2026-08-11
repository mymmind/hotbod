import Foundation

enum PhysiqueReassessReminderPlanner {
    static let identifier = PhysiqueReassessCadence.notificationIdentifier

    static func title() -> String { "Time to reassess" }

    static func body() -> String {
        "Capture updated photos and refresh your Physique focus."
    }
}

protocol PhysiqueReassessReminderScheduling: AnyObject, Sendable {
    func requestAuthorizationIfNeeded() async -> Bool
    func reschedule(profile: UserProfile, assessmentCreatedAt: Date?) async
    func cancelAll() async
}

final class NoOpPhysiqueReassessReminderScheduler: PhysiqueReassessReminderScheduling, @unchecked Sendable {
    func requestAuthorizationIfNeeded() async -> Bool { false }
    func reschedule(profile: UserProfile, assessmentCreatedAt: Date?) async {}
    func cancelAll() async {}
}
