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

        static let weightHardBlockTitle = String(localized: "workout.weightSanity.hard.title")
        static let weightHardBlockMessage = String(localized: "workout.weightSanity.hard.message")
        static let weightSoftWarningTitle = String(localized: "workout.weightSanity.soft.title")
        static let weightSanityEdit = String(localized: "workout.weightSanity.edit")
        static let weightSanitySaveAnyway = String(localized: "workout.weightSanity.saveAnyway")

        static func weightSoftWarningMessage(enteredKg: String, baselineKg: String) -> String {
            String(
                format: String(localized: "workout.weightSanity.soft.message"),
                locale: .current,
                enteredKg,
                baselineKg
            )
        }
    }
}
