import XCTest
@testable import HotBod

@MainActor
final class AppEnvironmentPersonalUseTests: XCTestCase {
    func testPresentPaywallNoOpWhenPersonalUseEnabled() {
        PersonalUseConfig.isEnabledOverride = true
        SubscriptionConfig.unrestrictedAccessOverride = nil
        defer {
            PersonalUseConfig.isEnabledOverride = nil
            SubscriptionConfig.unrestrictedAccessOverride = nil
        }

        let env = AppEnvironment.makeForTests()
        env.presentPaywall(for: .unlimitedGeneration)

        XCTAssertNil(env.paywallFeature)
        XCTAssertTrue(env.canAccess(.coachWorkoutApply))
        XCTAssertTrue(env.canAccess(.bodyPhotoHistory))
        XCTAssertTrue(env.canAccess(.workoutExport))
    }
}

@MainActor
final class AppEnvironmentPersonalUseBootstrapTests: XCTestCase {
    func testBootstrapSkipsSessionRestoreWhenPersonalUseEnabled() async {
        PersonalUseConfig.isEnabledOverride = true
        defer { PersonalUseConfig.isEnabledOverride = nil }

        let auth = SessionRestoringAuthService()
        let env = AppEnvironment.makeForTests(authService: auth)
        await env.bootstrap()

        XCTAssertEqual(auth.restoreCalls, 0)
        XCTAssertFalse(env.isSignedIn)
        XCTAssertNil(env.authEmail)
    }

    func testBootstrapRestoresSessionWhenPersonalUseDisabled() async {
        PersonalUseConfig.isEnabledOverride = false
        defer { PersonalUseConfig.isEnabledOverride = nil }

        let auth = SessionRestoringAuthService()
        let env = AppEnvironment.makeForTests(authService: auth)
        await env.bootstrap()

        XCTAssertEqual(auth.restoreCalls, 1)
        XCTAssertTrue(env.isSignedIn)
        XCTAssertEqual(env.authEmail, "test@example.com")
    }
}

private final class SessionRestoringAuthService: AuthService, @unchecked Sendable {
    var isAvailable: Bool { true }
    private(set) var restoreCalls = 0

    func currentUserId() async -> UUID? { UUID() }
    func currentEmail() async -> String? { "test@example.com" }
    func signUp(email: String, password: String) async throws {}
    func signIn(email: String, password: String) async throws {}
    func signOut() async throws {}
    func deleteAccount() async throws {}
    func restoreSession() async -> Bool {
        restoreCalls += 1
        return true
    }
}
