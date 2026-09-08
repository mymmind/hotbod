import Foundation

enum PersonalUseConfig {
    /// Set to `false` before any public, TestFlight, or App Store release.
    /// While enabled, this unlocks Pro, hides account UI, and skips remote intelligence.
    static let defaultIsEnabled = true

    /// Unit-test seam. Always clear in `defer`/tearDown.
    nonisolated(unsafe) static var isEnabledOverride: Bool?

    static var isEnabled: Bool {
        isEnabledOverride ?? defaultIsEnabled
    }

    static func shouldShowCloudAccountUI(supabaseConfigured: Bool) -> Bool {
        supabaseConfigured && !isEnabled
    }

    static var shouldUseRemoteIntelligence: Bool { !isEnabled }
}
