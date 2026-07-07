import Foundation

#if canImport(Supabase)
import Supabase

actor SupabaseAuthService: AuthService {
    private let client: SupabaseClient

    nonisolated var isAvailable: Bool { true }

    init(client: SupabaseClient) {
        self.client = client
    }

    func currentUserId() async -> UUID? {
        guard let session = try? await client.auth.session else { return nil }
        return session.user.id
    }

    func currentEmail() async -> String? {
        try? await client.auth.session.user.email
    }

    func signUp(email: String, password: String) async throws {
        _ = try await client.auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func restoreSession() async -> Bool {
        (try? await client.auth.session) != nil
    }
}

#endif
