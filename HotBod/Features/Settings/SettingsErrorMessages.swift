import Foundation

enum SettingsErrorMessages {
    static func auth(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("password") || message.contains("credential") {
            return "Could not sign in. Check your email and password."
        }
        if message.contains("network") || message.contains("internet") || message.contains("offline") {
            return "No connection. Try again when you are back online."
        }
        return "Something went wrong while signing in. Please try again."
    }

    static func delete(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("network") || message.contains("internet") || message.contains("offline") {
            return "No connection. Try again when you are back online."
        }
        return "Could not delete your data. Please try again."
    }

    static func save(syncMessage: String?) -> String {
        guard let syncMessage else { return "Could not save settings." }
        let normalized = syncMessage.lowercased()
        if normalized.contains("network") || normalized.contains("offline") {
            return "Could not save settings while offline. Try again when connected."
        }
        if normalized.contains("auth") || normalized.contains("sign in") {
            return "Sign in again to save these settings to cloud."
        }
        return "Could not save settings. Please try again."
    }
}
