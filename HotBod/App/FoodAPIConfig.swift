import Foundation

enum FoodAPIConfig {
    /// When set, overrides `isConfigured` for unit tests (e.g. forcing not-configured).
    nonisolated(unsafe) static var testOverrideConfigured: Bool?

    static var apiKey: String? {
        if testOverrideConfigured == false { return nil }
        if let envKey = ProcessInfo.processInfo.environment["USDA_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        return PlistSecrets.string(resource: "FoodAPIConfig", key: "USDA_API_KEY")
    }

    static var isConfigured: Bool {
        if let testOverrideConfigured { return testOverrideConfigured }
        guard let apiKey else { return false }
        return !apiKey.contains("YOUR_")
    }
}
