import XCTest
@testable import HotBod

final class SettingsDraftEditingTests: XCTestCase {
    func testShouldRefreshWorkoutIgnoresKettlebellSchemeOnlyChange() {
        let original = UserProfile.empty()
        var draft = original
        draft.kettlebellCircuitScheme = KettlebellCircuitScheme(
            exerciseCount: 3,
            reps: 4,
            rounds: 6,
            transitionRestSeconds: 20,
            roundRestSeconds: 90
        )
        XCTAssertFalse(SettingsDraftEditing.shouldRefreshWorkout(draft: draft, comparedTo: original))
    }

    func testShouldRefreshWorkoutStillTrueForEquipmentChange() {
        let original = UserProfile.empty()
        var draft = original
        draft.availableEquipment = [.kettlebell, .bodyweight]
        XCTAssertTrue(SettingsDraftEditing.shouldRefreshWorkout(draft: draft, comparedTo: original))
    }
}
