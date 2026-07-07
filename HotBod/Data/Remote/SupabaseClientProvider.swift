import Foundation

#if canImport(Supabase)
import Supabase

enum SupabaseClientProvider {
    static let shared: SupabaseClient? = {
        guard SupabaseConfig.isConfigured,
              let url = SupabaseConfig.url,
              let key = SupabaseConfig.anonKey else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()
}
#else

enum SupabaseClientProvider {
    static let shared: Any? = nil
}

#endif
