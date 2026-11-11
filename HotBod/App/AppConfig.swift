import Foundation

enum AppConfig {
    static let appName = "HotBod"

    /// Shown in Settings. Reads the shipped marketing version so the row cannot drift from the build.
    static var marketingVersion: String {
        guard
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            !version.isEmpty
        else { return "1.0.0" }
        return version
    }
}
