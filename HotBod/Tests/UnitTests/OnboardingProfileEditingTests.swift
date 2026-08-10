import XCTest
@testable import HotBod

@MainActor
final class OnboardingProfileEditingTests: XCTestCase {
    func testNormalizeBodyStatsFillsMissingValues() {
        var profile = UserProfile.empty()
        profile.weightKg = nil
        profile.heightCm = nil
        profile.age = nil

        OnboardingProfileEditing.normalizeBodyStats(&profile)

        XCTAssertEqual(profile.weightKg, 80)
        XCTAssertEqual(profile.heightCm, 175)
        XCTAssertEqual(profile.age, 30)
    }

    func testNormalizeLimitationsDefaultsToNone() {
        var profile = UserProfile.empty()
        profile.limitations = []

        OnboardingProfileEditing.normalizeLimitations(&profile)

        XCTAssertEqual(profile.limitations, [.none])
    }

    func testApplyLocationSetsEquipmentForBodyweightOnly() {
        var profile = UserProfile.empty()

        OnboardingProfileEditing.applyLocation(.bodyweightOnly, to: &profile)

        XCTAssertEqual(profile.trainingLocation, .bodyweightOnly)
        XCTAssertEqual(profile.availableEquipment, [.bodyweight])
    }

    func testApplyLocationPreservesCustomEquipmentWhenLocationUnchanged() {
        var profile = UserProfile.empty()
        profile.trainingLocation = .homeGym
        profile.availableEquipment = [.bodyweight, .dumbbell]

        OnboardingProfileEditing.applyLocation(.homeGym, to: &profile)

        XCTAssertEqual(profile.availableEquipment, [.bodyweight, .dumbbell])
    }

    func testNormalizeForCompletionRespectsLockedSplit() {
        var profile = UserProfile.empty()
        profile.preferredSplit = .arnold

        OnboardingProfileEditing.normalizeForCompletion(&profile, lockSplit: true)

        XCTAssertEqual(profile.preferredSplit, .arnold)
    }

    func testToggleEquipmentPreventsRemovingLastItem() {
        var profile = UserProfile.empty()
        profile.availableEquipment = [.bodyweight]

        OnboardingProfileEditing.toggleEquipment(.bodyweight, in: &profile)

        XCTAssertEqual(profile.availableEquipment, [.bodyweight])
    }

    func testToggleTrainingDayUpdatesDaysPerWeek() {
        var profile = UserProfile.empty()
        profile.reminderTrainingDays = [.monday]

        OnboardingProfileEditing.toggleTrainingDay(.wednesday, in: &profile)

        XCTAssertEqual(profile.reminderTrainingDays, [.monday, .wednesday])
        XCTAssertEqual(profile.trainingDaysPerWeek, 2)
    }

    func testRegression_onboardingScheduleDerivesFrequencyFromSelectedDays() {
        var profile = UserProfile.empty()
        profile.reminderTrainingDays = [.friday, .monday, .wednesday, .monday]

        OnboardingProfileEditing.reconcileSchedule(&profile)

        XCTAssertEqual(profile.reminderTrainingDays, [.monday, .wednesday, .friday])
        XCTAssertEqual(profile.trainingDaysPerWeek, 3)
    }

    func testRegression_onboardingScheduleCannotDropBelowTwoDays() {
        var profile = UserProfile.empty()
        profile.reminderTrainingDays = [.monday, .wednesday]

        let changed = OnboardingProfileEditing.toggleTrainingDay(.monday, in: &profile)

        XCTAssertFalse(changed)
        XCTAssertEqual(profile.reminderTrainingDays, [.monday, .wednesday])
    }

    func testSuggestedSplitMatchesFrequency() {
        XCTAssertEqual(OnboardingProfileEditing.suggestedSplit(for: 3), .fullBody)
        XCTAssertEqual(OnboardingProfileEditing.suggestedSplit(for: 4), .upperLower)
        XCTAssertEqual(OnboardingProfileEditing.suggestedSplit(for: 5), .pushPullLegs)
        XCTAssertEqual(OnboardingProfileEditing.suggestedSplit(for: 7), .adaptive)
    }

    func testNormalizeForCompletionReconcilesScheduleAndSplit() {
        var profile = UserProfile.empty()
        profile.reminderTrainingDays = [.monday, .wednesday, .friday]
        profile.limitations = []
        profile.weightKg = nil

        OnboardingProfileEditing.normalizeForCompletion(&profile)

        XCTAssertEqual(profile.trainingDaysPerWeek, 3)
        XCTAssertEqual(profile.preferredSplit, .fullBody)
        XCTAssertEqual(profile.limitations, [.none])
        XCTAssertEqual(profile.weightKg, 80)
    }
}
