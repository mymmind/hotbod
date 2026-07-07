import Foundation

enum GeminiConfig {
    static var apiKey: String? {
        PlistSecrets.string(resource: "GeminiConfig", key: "GEMINI_API_KEY")
    }

    static var model: String? {
        PlistSecrets.string(resource: "GeminiConfig", key: "GEMINI_MODEL") ?? "gemini-1.5-flash"
    }

    static var isConfigured: Bool {
        guard let apiKey else { return false }
        return !apiKey.isEmpty && !apiKey.contains("YOUR_")
    }
}
