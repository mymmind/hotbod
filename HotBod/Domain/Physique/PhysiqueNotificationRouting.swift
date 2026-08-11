import Foundation

enum PhysiqueNotificationRouting {
    static func shouldOpenPhysique(identifier: String) -> Bool {
        identifier.hasPrefix(PhysiqueReassessCadence.notificationIdentifier)
    }
}
