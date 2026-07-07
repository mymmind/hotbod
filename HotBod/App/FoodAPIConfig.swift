import Foundation

enum FoodAPIConfig {
    static var apiKey: String? {
        PlistSecrets.string(resource: "FoodAPIConfig", key: "USDA_API_KEY")
    }

    static var isConfigured: Bool {
        guard let apiKey else { return false }
        return !apiKey.contains("YOUR_")
    }
}
