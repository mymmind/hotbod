import XCTest
@testable import HotBod

final class SessionSetEditorTests: XCTestCase {
    func testRegression_additionalSetGetsUniqueId() {
        let original = PlannedSet(
            targetRepsMin: 4,
            targetRepsMax: 6,
            targetWeightKg: 110,
            rpeTarget: 8
        )

        let added = SessionSetEditor.additionalSet(copying: original)

        XCTAssertNotEqual(
            added.id,
            original.id,
            "Add Set must mint a new PlannedSet id; duplicate ids make two rows share completion/RPE state"
        )
        XCTAssertEqual(added.targetRepsMin, original.targetRepsMin)
        XCTAssertEqual(added.targetRepsMax, original.targetRepsMax)
        XCTAssertEqual(added.targetWeightKg, original.targetWeightKg)
        XCTAssertEqual(added.rpeTarget, original.rpeTarget)
        XCTAssertFalse(added.isWarmup)
        XCTAssertFalse(added.isMaxEffort)
        XCTAssertFalse(added.isCooldown)
    }

    func testAdditionalSetDefaultsWhenNoPriorSet() {
        let added = SessionSetEditor.additionalSet(copying: nil)
        XCTAssertEqual(added.targetRepsMin, 8)
        XCTAssertEqual(added.targetRepsMax, 10)
    }
}
