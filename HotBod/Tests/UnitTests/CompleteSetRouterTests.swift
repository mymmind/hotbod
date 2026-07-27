import XCTest
@testable import HotBod

final class CompleteSetRouterTests: XCTestCase {
    func testRegression_editingCompletedSetUpdatesInsteadOfAdvancing() {
        // Accidental complete on set 0, user focuses that row.
        let target = CompleteSetRouter.target(
            plannedCount: 3,
            completedSetIndexes: [0],
            focusedSetIndex: 0
        )
        XCTAssertEqual(target, .updateCompleted(setIndex: 0))
        XCTAssertEqual(CompleteSetRouter.buttonTitle(for: target), "Update Set")
    }

    func testCompletesActiveWhenFocusNil() {
        let target = CompleteSetRouter.target(
            plannedCount: 3,
            completedSetIndexes: [0],
            focusedSetIndex: nil
        )
        XCTAssertEqual(target, .completeActive(setIndex: 1))
        XCTAssertEqual(CompleteSetRouter.buttonTitle(for: target), "Complete Set")
    }

    func testCompletesActiveWhenFocusOnActiveSet() {
        let target = CompleteSetRouter.target(
            plannedCount: 3,
            completedSetIndexes: [0],
            focusedSetIndex: 1
        )
        XCTAssertEqual(target, .completeActive(setIndex: 1))
    }

    func testCompletesFirstSetWhenNothingCompleted() {
        let target = CompleteSetRouter.target(
            plannedCount: 3,
            completedSetIndexes: [],
            focusedSetIndex: nil
        )
        XCTAssertEqual(target, .completeActive(setIndex: 0))
    }

    func testNoneWhenAllSetsDoneAndNoFocus() {
        let target = CompleteSetRouter.target(
            plannedCount: 2,
            completedSetIndexes: [0, 1],
            focusedSetIndex: nil
        )
        XCTAssertEqual(target, .none)
    }

    func testUpdatesCompletedWhenAllSetsDoneButPastFocused() {
        let target = CompleteSetRouter.target(
            plannedCount: 2,
            completedSetIndexes: [0, 1],
            focusedSetIndex: 1
        )
        XCTAssertEqual(target, .updateCompleted(setIndex: 1))
    }

    func testUpdatesPlannedFutureSetWithoutCompleting() {
        let target = CompleteSetRouter.target(
            plannedCount: 3,
            completedSetIndexes: [0],
            focusedSetIndex: 2
        )
        XCTAssertEqual(target, .updatePlanned(setIndex: 2))
        XCTAssertEqual(CompleteSetRouter.buttonTitle(for: target), "Update Set")
    }

    func testIgnoresOutOfRangeFocus() {
        let target = CompleteSetRouter.target(
            plannedCount: 3,
            completedSetIndexes: [0],
            focusedSetIndex: 9
        )
        XCTAssertEqual(target, .completeActive(setIndex: 1))
    }
}
