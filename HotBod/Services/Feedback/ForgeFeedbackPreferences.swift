import Foundation

enum ForgeFeedbackPreferences {
    private static let hapticsKey = "forge.feedback.hapticsEnabled"
    private static let soundsKey = "forge.feedback.soundsEnabled"

    static var hapticsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: hapticsKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: hapticsKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: hapticsKey) }
    }

    static var soundsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: soundsKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: soundsKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: soundsKey) }
    }
}
