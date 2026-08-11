import UIKit
import XCTest
@testable import HotBod

private struct FixedPhysiqueAssessmentService: PhysiqueAssessmentServing, Sendable {
    let assessment: PhysiqueAssessment

    func assess(_ request: PhysiqueAssessmentRequest) async throws -> PhysiqueAssessment {
        var result = assessment
        result.frontPhotoId = request.selection.front.id
        result.backPhotoId = request.selection.back?.id
        result.sidePhotoId = request.selection.side?.id
        return result
    }
}

@MainActor
final class AppEnvironmentPhysiqueOrchestrationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PhysiqueSplitSuggestionPreferences.clear()
    }

    override func tearDown() {
        PhysiqueSplitSuggestionPreferences.clear()
        super.tearDown()
    }

    func testPhysiqueSplitSuggestionAppearsForMismatchedFullBody() async throws {
        let setup = try await makeSplitSuggestionSetup()
        let suggestion = setup.env.physiqueSplitSuggestion(
            for: setup.assessment,
            profile: setup.profile
        )
        XCTAssertEqual(suggestion?.to, .pushPullLegs)
        XCTAssertEqual(suggestion?.from, .fullBody)
    }

    func testDismissPhysiqueSplitSuggestionHidesCard() async throws {
        let setup = try await makeSplitSuggestionSetup()
        let suggestion = setup.env.physiqueSplitSuggestion(
            for: setup.assessment,
            profile: setup.profile
        )
        XCTAssertNotNil(suggestion)
        setup.env.dismissPhysiqueSplitSuggestion(assessmentId: setup.assessment.id)
        XCTAssertNil(
            setup.env.physiqueSplitSuggestion(for: setup.assessment, profile: setup.profile)
        )
    }

    func testApplyPhysiqueSplitSuggestionUpdatesSplitResetsIndexAndHandles() async throws {
        let setup = try await makeSplitSuggestionSetup(
            workoutGenerationService: FixedMockWorkoutGenerationService(
                workout: FixtureBuilders.makeGeneratedWorkout()
            )
        )
        setup.env.programState.splitDayIndex = 2
        try await setup.repos.programState.saveState(setup.env.programState)

        guard let suggestion = setup.env.physiqueSplitSuggestion(
            for: setup.assessment,
            profile: setup.profile
        ) else {
            return XCTFail("expected suggestion")
        }
        let ok = await setup.env.applyPhysiqueSplitSuggestion(suggestion)
        XCTAssertTrue(ok)
        XCTAssertEqual(setup.env.userProfile?.preferredSplit, .pushPullLegs)
        XCTAssertEqual(setup.env.programState.splitDayIndex, 0)
        XCTAssertNil(
            setup.env.physiqueSplitSuggestion(
                for: setup.assessment,
                profile: setup.env.userProfile!
            )
        )
    }

    func testRegression_applyPhysiqueSplitSuggestionRollsBackOnRegenerateFailure() async throws {
        let setup = try await makeSplitSuggestionSetup(
            workoutGenerationService: FailingMockWorkoutGenerationService()
        )
        setup.env.programState.splitDayIndex = 2
        try await setup.repos.programState.saveState(setup.env.programState)

        guard let suggestion = setup.env.physiqueSplitSuggestion(
            for: setup.assessment,
            profile: setup.profile
        ) else {
            return XCTFail("expected suggestion")
        }
        let ok = await setup.env.applyPhysiqueSplitSuggestion(suggestion)
        XCTAssertFalse(ok)
        XCTAssertEqual(setup.env.userProfile?.preferredSplit, .fullBody)
        XCTAssertEqual(setup.env.programState.splitDayIndex, 2)
        XCTAssertNotEqual(
            PhysiqueSplitSuggestionPreferences.dismissedAssessmentId,
            setup.assessment.id
        )
        XCTAssertNotNil(
            setup.env.physiqueSplitSuggestion(
                for: setup.assessment,
                profile: setup.env.userProfile!
            )
        )
    }

    func testRegression_wipeClearsPhysiqueSplitSuggestionDismissal() async throws {
        PhysiqueSplitSuggestionPreferences.markHandled(assessmentId: UUID())
        XCTAssertNotNil(PhysiqueSplitSuggestionPreferences.dismissedAssessmentId)
        let env = AppEnvironment.makeForTests()
        try await env.wipeAllLocalUserData(clearAuthSession: false)
        XCTAssertNil(PhysiqueSplitSuggestionPreferences.dismissedAssessmentId)
    }

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

    func testRegression_assessPhysiqueFrontOnlySucceeds() async throws {
        let repos = TestRepositories.empty()
        var profile = UserProfile.empty()
        profile.photoTrackingEnabled = true
        try await repos.userProfile.saveProfile(profile)
        try await repos.userProfile.setOnboardingComplete(true)

        let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed, userId: profile.id)
        try await repos.bodyProgress.savePhoto(front)

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

        let result = await env.assessPhysique(photos: [front])
        XCTAssertNotNil(result)
        XCTAssertNil(result?.backPhotoId)
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

    func testLoadActivePhysiqueAssessmentPopulatesHistory() async throws {
        let repos = TestRepositories.empty()
        let older = FixtureBuilders.makePhysiqueAssessment(createdAt: Date(timeIntervalSince1970: 1))
        let newer = FixtureBuilders.makePhysiqueAssessment(createdAt: Date(timeIntervalSince1970: 2))
        try await repos.physiqueAssessment.saveActive(older)
        try await repos.physiqueAssessment.saveActive(newer)
        let env = AppEnvironment.makeForTests(repos: repos)
        await env.loadActivePhysiqueAssessment()
        XCTAssertEqual(env.activePhysiqueAssessment?.id, newer.id)
        XCTAssertEqual(env.physiqueAssessmentHistory.map(\.id), [newer.id, older.id])
    }

    func testRegression_trainingBiasUsesNewestAssessmentOnly() async throws {
        let repos = TestRepositories.empty()
        var profile = UserProfile.empty()
        profile.preferredMuscleGroups = []
        try await repos.userProfile.saveProfile(profile)

        var older = FixtureBuilders.makePhysiqueAssessment(createdAt: Date(timeIntervalSince1970: 1))
        older.trainingBias = PhysiqueTrainingBias(
            preferredMuscleGroups: [.quads],
            rationale: "old"
        )
        var newer = FixtureBuilders.makePhysiqueAssessment(createdAt: Date(timeIntervalSince1970: 2))
        newer.trainingBias = PhysiqueTrainingBias(
            preferredMuscleGroups: [.shoulders, .back],
            rationale: "new"
        )
        try await repos.physiqueAssessment.saveActive(older)
        try await repos.physiqueAssessment.saveActive(newer)

        let env = AppEnvironment.makeForTests(repos: repos)
        env.userProfile = profile
        await env.loadActivePhysiqueAssessment()
        let input = await env.makeWorkoutGenerationInput(profile: profile, splitDayFocus: .push)
        XCTAssertEqual(input.preferredMuscleGroups, [.shoulders, .back])
        XCTAssertFalse(input.preferredMuscleGroups.contains(.quads))
    }

    func testMakeWorkoutGenerationInputSetsPhysiquePreferredFromActiveAssessment() async throws {
        let repos = TestRepositories.empty()
        var profile = UserProfile.empty()
        profile.preferredMuscleGroups = [.quads]
        profile.avoidedMuscleGroups = [.chest]
        try await repos.userProfile.saveProfile(profile)

        var assessment = FixtureBuilders.makePhysiqueAssessment()
        assessment.trainingBias = PhysiqueTrainingBias(
            preferredMuscleGroups: [.shoulders, .chest, .back],
            rationale: "test"
        )
        try await repos.physiqueAssessment.saveActive(assessment)

        let env = AppEnvironment.makeForTests(repos: repos)
        env.userProfile = profile
        await env.loadActivePhysiqueAssessment()

        let input = await env.makeWorkoutGenerationInput(profile: profile, splitDayFocus: .push)
        XCTAssertEqual(input.physiquePreferredMuscleGroups, [.shoulders, .back])
        XCTAssertTrue(input.preferredMuscleGroups.contains(.shoulders))
        XCTAssertTrue(input.preferredMuscleGroups.contains(.quads))
        XCTAssertFalse(input.physiquePreferredMuscleGroups.contains(.chest))
        XCTAssertFalse(input.physiquePreferredMuscleGroups.contains(.quads))
    }

    func testMakeWorkoutGenerationInputPhysiquePreferredEmptyWithoutAssessment() async {
        let repos = TestRepositories.empty()
        var profile = UserProfile.empty()
        profile.preferredMuscleGroups = [.quads]
        try? await repos.userProfile.saveProfile(profile)
        try? await repos.userProfile.setOnboardingComplete(true)

        let env = AppEnvironment.makeForTests(repos: repos)
        env.userProfile = profile
        env.hasCompletedOnboarding = true

        let input = await env.makeWorkoutGenerationInput(profile: profile, splitDayFocus: .push)
        XCTAssertEqual(input.physiquePreferredMuscleGroups, [])
    }

    func testRegression_physiquePreferredUsesNewestAssessmentOnly() async throws {
        let repos = TestRepositories.empty()
        var profile = UserProfile.empty()
        profile.preferredMuscleGroups = []
        try await repos.userProfile.saveProfile(profile)

        var older = FixtureBuilders.makePhysiqueAssessment(createdAt: Date(timeIntervalSince1970: 1))
        older.trainingBias = PhysiqueTrainingBias(
            preferredMuscleGroups: [.quads],
            rationale: "old"
        )
        var newer = FixtureBuilders.makePhysiqueAssessment(createdAt: Date(timeIntervalSince1970: 2))
        newer.trainingBias = PhysiqueTrainingBias(
            preferredMuscleGroups: [.shoulders, .back],
            rationale: "new"
        )
        try await repos.physiqueAssessment.saveActive(older)
        try await repos.physiqueAssessment.saveActive(newer)

        let env = AppEnvironment.makeForTests(repos: repos)
        env.userProfile = profile
        await env.loadActivePhysiqueAssessment()
        let input = await env.makeWorkoutGenerationInput(profile: profile, splitDayFocus: .push)
        XCTAssertEqual(input.physiquePreferredMuscleGroups, [.shoulders, .back])
        XCTAssertFalse(input.physiquePreferredMuscleGroups.contains(.quads))
    }

    func testSinceLastPhysiqueDiffNilWithSingleAssessment() async throws {
        let repos = TestRepositories.empty()
        try await repos.physiqueAssessment.saveActive(FixtureBuilders.makePhysiqueAssessment())
        let env = AppEnvironment.makeForTests(repos: repos)
        await env.loadActivePhysiqueAssessment()
        XCTAssertNil(env.sinceLastPhysiqueDiff(photos: []))
    }

    func testRegression_trendAdaptRewritesBiasNotPriorities() async throws {
        let repos = TestRepositories.empty()
        var profile = UserProfile.empty()
        profile.photoTrackingEnabled = true
        try await repos.userProfile.saveProfile(profile)
        try await repos.userProfile.setOnboardingComplete(true)

        var older = FixtureBuilders.makePhysiqueAssessment(
            createdAt: Date(timeIntervalSince1970: 1)
        )
        older.developmentPriorities = [
            .init(muscle: .lats, reason: "width"),
            .init(muscle: .upperChest, reason: "shelf")
        ]
        older.trainingBias = PhysiqueTrainingBias(
            preferredMuscleGroups: [.back, .chest],
            rationale: "old"
        )
        try await repos.physiqueAssessment.saveActive(older)

        let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed, userId: profile.id)
        let back = FixtureBuilders.makeBodyPhoto(pose: .backRelaxed, userId: profile.id)

        var newer = FixtureBuilders.makePhysiqueAssessment(
            createdAt: Date(timeIntervalSince1970: 2),
            frontPhotoId: front.id,
            backPhotoId: back.id
        )
        newer.developmentPriorities = [
            .init(muscle: .lateralDelts, reason: "caps"),
            .init(muscle: .lats, reason: "width")
        ]
        newer.trainingBias = PhysiqueTrainingBias(
            preferredMuscleGroups: [.shoulders, .back],
            rationale: "from assessor"
        )
        newer.trendAdaptation = nil

        let env = AppEnvironment.makeForTests(
            repos: repos,
            physiqueAssessmentService: HybridPhysiqueAssessmentService(
                remote: FixedPhysiqueAssessmentService(assessment: newer),
                offline: OfflinePhysiqueAssessmentService(),
                analyzer: MockBodyPhotoAnalyzer()
            )
        )
        env.userProfile = profile
        env.hasCompletedOnboarding = true

        let result = await env.assessPhysique(photos: [front, back])

        XCTAssertEqual(result?.developmentPriorities.map(\.muscle), [.lateralDelts, .lats])
        XCTAssertEqual(result?.trainingBias.preferredMuscleGroups.first, .shoulders)
        XCTAssertNotNil(result?.trendAdaptation)
        XCTAssertTrue(result?.trendAdaptation?.reasons.contains { $0.contains("appeared") } == true)
        XCTAssertEqual(env.activePhysiqueAssessment?.trendAdaptation?.previousAssessmentId, older.id)
    }

    func testRegression_wipeClearsPhysiqueInMemoryState() async throws {
        let env = AppEnvironment.makeForTests()
        let assessment = FixtureBuilders.makePhysiqueAssessment()
        env.activePhysiqueAssessment = assessment
        env.physiqueAssessmentHistory = [assessment]
        env.physiqueStatusMessage = "Offline analysis used."

        try await env.wipeAllLocalUserData()

        XCTAssertNil(env.activePhysiqueAssessment)
        XCTAssertTrue(env.physiqueAssessmentHistory.isEmpty)
        XCTAssertNil(env.physiqueStatusMessage)
    }

    func testGeneratePhysiqueIllustrationPersistsWithMock() async throws {
        let repos = TestRepositories.empty()
        var profile = UserProfile.empty()
        try await repos.userProfile.saveProfile(profile)
        try await repos.userProfile.setOnboardingComplete(true)
        let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed, userId: profile.id)
        try writeBodyPhotoFile(for: front)
        try await repos.bodyProgress.savePhoto(front)
        var assessment = FixtureBuilders.makePhysiqueAssessment()
        assessment.frontPhotoId = front.id
        try await repos.physiqueAssessment.saveActive(assessment)

        let env = AppEnvironment.makeForTests(
            repos: repos,
            physiqueIllustrationService: MockPhysiqueIllustrationService()
        )
        env.userProfile = profile
        env.hasCompletedOnboarding = true
        await env.loadActivePhysiqueAssessment()
        await env.generatePhysiqueIllustration(assessment: assessment, photos: [front])
        XCTAssertNotNil(env.physiqueIllustration)
        XCTAssertEqual(env.physiqueIllustration?.assessmentId, assessment.id)
        XCTAssertFalse(env.isGeneratingPhysiqueIllustration)
    }

    func testRegression_loadPhysiqueIllustrationClearsWhenAssessmentDiffers() async throws {
        let repos = TestRepositories.empty()
        var profile = UserProfile.empty()
        try await repos.userProfile.saveProfile(profile)
        try await repos.userProfile.setOnboardingComplete(true)
        let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed, userId: profile.id)
        try writeBodyPhotoFile(for: front)
        try await repos.bodyProgress.savePhoto(front)
        var assessmentA = FixtureBuilders.makePhysiqueAssessment()
        assessmentA.frontPhotoId = front.id
        try await repos.physiqueAssessment.saveActive(assessmentA)

        let assessmentB = FixtureBuilders.makePhysiqueAssessment()

        let env = AppEnvironment.makeForTests(
            repos: repos,
            physiqueIllustrationService: MockPhysiqueIllustrationService()
        )
        env.userProfile = profile
        env.hasCompletedOnboarding = true

        await env.generatePhysiqueIllustration(assessment: assessmentA, photos: [front])
        XCTAssertNotNil(env.physiqueIllustrationImageData)
        XCTAssertEqual(env.physiqueIllustration?.assessmentId, assessmentA.id)

        await env.loadPhysiqueIllustration(for: assessmentB.id)
        XCTAssertNil(env.physiqueIllustration)
        XCTAssertNil(env.physiqueIllustrationImageData)
    }

    func testRegression_wipeClearsPhysiqueIllustration() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistenceOnMainActor {
            let repos = TestRepositories.empty()
            let env = AppEnvironment.makeForTests(repos: repos)
            let assessmentId = UUID()
            let photoId = UUID()
            let jpeg = PhysiqueIllustrationImageCodec.jpegDataForUpload(
                from: UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in }
            )!
            let record = try await env.physiqueIllustrationStore.save(
                assessmentId: assessmentId,
                sourcePhotoId: photoId,
                imageData: jpeg
            )
            env.physiqueIllustration = record
            env.physiqueIllustrationImageData = jpeg
            env.physiqueIllustrationStatus = "Ready"

            try await env.wipeAllLocalUserData()

            XCTAssertNil(env.physiqueIllustration)
            XCTAssertNil(env.physiqueIllustrationImageData)
            XCTAssertNil(env.physiqueIllustrationStatus)
            XCTAssertFalse(env.isGeneratingPhysiqueIllustration)
            let fetched = try await env.physiqueIllustrationStore.fetch(assessmentId: assessmentId)
            XCTAssertNil(fetched)
        }
    }

    func testRegression_assessPhysiqueReschedulesReassessReminder() async throws {
        let recorder = RecordingPhysiqueReassessReminderScheduler()
        let repos = TestRepositories.empty()
        var profile = UserProfile.empty()
        profile.photoTrackingEnabled = true
        profile.workoutRemindersEnabled = true
        try await repos.userProfile.saveProfile(profile)
        try await repos.userProfile.setOnboardingComplete(true)

        let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed, userId: profile.id)
        let back = FixtureBuilders.makeBodyPhoto(pose: .backRelaxed, userId: profile.id)
        try await repos.bodyProgress.savePhoto(front)
        try await repos.bodyProgress.savePhoto(back)

        let assessment = FixtureBuilders.makePhysiqueAssessment(
            frontPhotoId: front.id,
            backPhotoId: back.id
        )
        let env = AppEnvironment.makeForTests(
            repos: repos,
            physiqueAssessmentService: HybridPhysiqueAssessmentService(
                remote: FixedPhysiqueAssessmentService(assessment: assessment),
                offline: OfflinePhysiqueAssessmentService(),
                analyzer: MockBodyPhotoAnalyzer()
            ),
            physiqueReassessReminderScheduler: recorder
        )
        env.userProfile = profile
        env.hasCompletedOnboarding = true

        _ = await env.assessPhysique(photos: [front, back])
        XCTAssertFalse(recorder.rescheduleCalls.isEmpty)
        XCTAssertNotNil(recorder.rescheduleCalls.last?.createdAt)
    }

    func testRegression_clearAccountCancelsPhysiqueReassessReminder() async throws {
        let recorder = RecordingPhysiqueReassessReminderScheduler()
        let env = AppEnvironment.makeForTests(physiqueReassessReminderScheduler: recorder)
        env.activePhysiqueAssessment = FixtureBuilders.makePhysiqueAssessment()
        env.physiqueAssessmentHistory = [env.activePhysiqueAssessment!]

        try await env.wipeAllLocalUserData(clearAuthSession: false)
        XCTAssertGreaterThan(recorder.cancelCount, 0)
    }

    func testRegression_remindersDisabledCancelsPhysiqueReassessOnReschedule() async throws {
        let recorder = RecordingPhysiqueReassessReminderScheduler()
        var profile = UserProfile.empty()
        profile.workoutRemindersEnabled = false
        let env = AppEnvironment.makeForTests(physiqueReassessReminderScheduler: recorder)
        env.userProfile = profile
        env.activePhysiqueAssessment = FixtureBuilders.makePhysiqueAssessment()

        await env.rescheduleAllLocalReminders()
        XCTAssertEqual(recorder.rescheduleCalls.last?.enabled, false)
    }
}

@MainActor
private struct SplitSuggestionSetup {
    let repos: TestRepositories
    let env: AppEnvironment
    let profile: UserProfile
    let assessment: PhysiqueAssessment
}

@MainActor
private func makeSplitSuggestionSetup(
    workoutGenerationService: (any WorkoutGenerationService)? = nil
) async throws -> SplitSuggestionSetup {
    let repos = TestRepositories.empty()
    var profile = UserProfile.empty()
    profile.preferredSplit = .fullBody
    profile.reminderTrainingDays = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday
    ]
    try await repos.userProfile.saveProfile(profile)

    var assessment = FixtureBuilders.makePhysiqueAssessment()
    assessment.trainingBias = PhysiqueTrainingBias(
        preferredMuscleGroups: [.shoulders, .back],
        rationale: "test"
    )
    try await repos.physiqueAssessment.saveActive(assessment)

    let env = AppEnvironment.makeForTests(
        repos: repos,
        workoutGenerationService: workoutGenerationService
    )
    env.userProfile = profile
    env.activePhysiqueAssessment = assessment
    return SplitSuggestionSetup(
        repos: repos,
        env: env,
        profile: profile,
        assessment: assessment
    )
}

private func writeBodyPhotoFile(for photo: BodyProgressPhoto) throws {
    let url = BodyPhotoPathResolver.resolve(photo.localImagePath)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in }
    guard let data = image.jpegData(compressionQuality: 0.85) else {
        struct MissingJPEG: Error {}
        throw MissingJPEG()
    }
    try data.write(to: url, options: .atomic)
}
