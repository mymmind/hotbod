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

    func testRegression_physiqueDirectionsDoNotChangeTrainingBias() async throws {
        let repos = TestRepositories.empty()
        var profile = UserProfile.empty()
        profile.preferredMuscleGroups = [.quads]
        profile.avoidedMuscleGroups = [.chest]
        try await repos.userProfile.saveProfile(profile)

        var assessment = FixtureBuilders.makePhysiqueAssessment()
        assessment.trainingBias = PhysiqueTrainingBias(
            preferredMuscleGroups: [.shoulders, .back, .chest],
            rationale: "V-taper focus"
        )
        assessment.physiqueDirections = [
            PhysiqueArchetypeMatch(
                archetypeId: "classic_athletic",
                rank: 1,
                similarityDimension: "Defined V-taper from shoulders to waist",
                confidence: .high
            ),
            PhysiqueArchetypeMatch(
                archetypeId: "lean_fighter",
                rank: 2,
                similarityDimension: "Lean silhouette with functional muscle tone",
                confidence: .medium
            )
        ]
        try await repos.physiqueAssessment.saveActive(assessment)

        let env = AppEnvironment.makeForTests(
            repos: repos,
            physiqueAssessmentService: HybridPhysiqueAssessmentService(
                remote: UnavailablePhysiqueAssessmentService(),
                offline: OfflinePhysiqueAssessmentService(),
                analyzer: MockBodyPhotoAnalyzer()
            )
        )
        env.userProfile = profile
        await env.loadActivePhysiqueAssessment()

        let expectedBias = PhysiqueTrainingBiasMerger.mergePreferredMuscleGroups(
            profilePreferred: profile.preferredMuscleGroups ?? [],
            assessmentBias: assessment.trainingBias.preferredMuscleGroups,
            avoided: profile.avoidedMuscleGroups ?? []
        )

        let input = await env.makeWorkoutGenerationInput(profile: profile, splitDayFocus: .push)
        XCTAssertEqual(input.preferredMuscleGroups, expectedBias)
        XCTAssertEqual(input.preferredMuscleGroups, [.shoulders, .back, .quads])
        XCTAssertFalse(assessment.physiqueDirections.isEmpty)
    }
}
