import Foundation

enum SupabaseConfig {
    static var url: URL? {
        PlistSecrets.string(resource: "SupabaseConfig", key: "SUPABASE_URL").flatMap(URL.init(string:))
    }

    static var anonKey: String? {
        PlistSecrets.string(resource: "SupabaseConfig", key: "SUPABASE_ANON_KEY")
    }

    static var isConfigured: Bool {
        guard let url, let anonKey else { return false }
        return !url.absoluteString.contains("YOUR_PROJECT_REF") && !anonKey.contains("YOUR_")
    }
}
