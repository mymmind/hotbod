import XCTest
@testable import HotBod

@MainActor
final class AppEnvironmentOrchestrationTests: XCTestCase {
    func testAssessPhysiquePersistsOnDeviceWhenRemoteUnavailable() async throws {
        let repos = TestRepositories.empty()
        var profile = UserProfile.empty()
        profile.photoTrackingEnabled = true
        try await repos.userProfile.saveProfile(profile)
        try await repos.userProfile.setOnboardingComplete(true)

        let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed, userId: profile.id)
        let back = FixtureBuilders.makeBodyPhoto(pose: .backRelaxed, userId: profile.id)
        try await repos.bodyProgress.savePhoto(front)
        try await repos.bodyProgress.savePhoto(back)

        let env = AppEnvironment.makeForTests(
            repos: repos,
            physiqueAssessmentService: HybridPhysiqueAssessmentService(
                remote: UnavailablePhysiqueAssessmentService(),
                offline: OfflinePhysiqueAssessmentService(),
                analyzer: MockBodyPhotoAnalyzer()
            )
        )
        env.userProfile = profile
        env.hasCompletedOnboarding = true

        let result = await env.assessPhysique(photos: [front, back])
        XCTAssertEqual(result?.source, .onDevice)
        XCTAssertEqual(env.activePhysiqueAssessment?.id, result?.id)
    }

    func testAssessPhysiqueBlockedWithoutBackPhoto() async throws {
        let repos = TestRepositories.empty()
        let profile = UserProfile.empty()
        let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed, userId: profile.id)
        try await repos.bodyProgress.savePhoto(front)
        let env = AppEnvironment.makeForTests(repos: repos)
        env.userProfile = profile
        env.hasCompletedOnboarding = true
        let result = await env.assessPhysique(photos: [front])
        XCTAssertNil(result)
    }
}
