import UIKit
import UserNotifications

final class HotBodAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var router: AppRouter?
    private var pendingOpenPhysique = false

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let id = response.notification.request.identifier
        guard PhysiqueNotificationRouting.shouldOpenPhysique(identifier: id) else { return }
        await openPhysiqueTab()
    }

    /// Opens Physique, or queues the intent when `router` is not yet wired (cold-start tap).
    @MainActor
    func openPhysiqueTab() {
        guard let router else {
            pendingOpenPhysique = true
            return
        }
        router.showMain()
        router.selectedTab = .physique
    }

    /// Flushes a queued Physique open after `router` is assigned (e.g. from `HotBodApp.onAppear`).
    @MainActor
    func flushPendingNavigation() {
        guard pendingOpenPhysique, router != nil else { return }
        pendingOpenPhysique = false
        openPhysiqueTab()
    }
}
