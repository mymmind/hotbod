import Foundation

/// Centralized localization keys. Add strings to `Localizable.xcstrings` as the app grows.
enum L10n {
    enum Settings {
        static let integrationsTitle = String(localized: "settings.integrations.title")
        static let integrationsSubtitle = String(localized: "settings.integrations.subtitle")
        static let healthExportTitle = String(localized: "settings.integrations.healthExport")
        static let healthExportHint = String(localized: "settings.integrations.healthExport.hint")
        static let stravaTitle = String(localized: "settings.integrations.strava")
        static let stravaComingSoon = String(localized: "settings.integrations.strava.comingSoon")
    }

    enum Workout {
        static let completeTitle = String(localized: "workout.complete.title")
    }
}
