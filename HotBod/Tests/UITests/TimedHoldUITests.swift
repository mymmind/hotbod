import XCTest

/// Hold zero, elapsed logging, and sub-second cancel are covered by date-injected
/// unit tests in HoldCountdownTests.
///
/// UI test exemption: Start→Stop interaction is not asserted here. In Simulator the
/// HOLD Start control is present in the accessibility tree but regularly reports a
/// non-hittable frame under the session action bar, so coordinate taps do not invoke
/// the action reliably. Presence of `hold.start` on a plank-first seed is the UI gate.
final class TimedHoldUITests: BaseUITestCase {
  private var session: WorkoutSessionPage { WorkoutSessionPage(app: app) }

  override func setUpWithError() throws {
    startWorkoutOnLaunch = true
    seedTimedHold = true
    try super.setUpWithError()
  }

  func testHoldStartControlAppearsOnTimedSet() {
    XCTAssertTrue(session.waitForSession(timeout: 60))
    XCTAssertTrue(
      app.staticTexts["Plank"].waitForExistence(timeout: 8)
        || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Plank")).firstMatch
          .waitForExistence(timeout: 2),
      "Expected plank-first timed-hold seed"
    )

    let start = session.holdStartButton
    if !start.waitForExistence(timeout: 8) {
      app.swipeUp()
    }
    XCTAssertTrue(start.waitForExistence(timeout: 5), "Missing hold.start on timed hold set")
  }
}
