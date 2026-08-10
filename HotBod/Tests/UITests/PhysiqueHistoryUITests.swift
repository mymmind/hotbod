import XCTest

final class PhysiqueHistoryUITests: BaseUITestCase {
  override func setUpWithError() throws {
    launchTab = "physique"
    seedPhysiqueHistory = true
    try super.setUpWithError()
  }

  private var historyList: XCUIElement {
    app.descendants(matching: .any)["physique.history.list"]
  }

  func testSinceLastVisibleWithTwoAssessments() {
    XCTAssertTrue(app.otherElements["physique.sinceLast"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["SINCE LAST ASSESSMENT"].exists)
  }

  func testHistoryListShowsCurrentBadge() {
    XCTAssertTrue(app.buttons["physique.history"].waitForExistence(timeout: 10))
    app.buttons["physique.history"].tap()
    XCTAssertTrue(historyList.waitForExistence(timeout: 8))
    XCTAssertTrue(app.staticTexts["Current"].waitForExistence(timeout: 5))
  }

  func testPastDetailHasNoReassess() {
    XCTAssertTrue(app.buttons["physique.history"].waitForExistence(timeout: 10))
    app.buttons["physique.history"].tap()
    XCTAssertTrue(historyList.waitForExistence(timeout: 8))

    let older = app.buttons["physique.history.00000000-0000-0000-0000-0000000000A1"]
    XCTAssertTrue(older.waitForExistence(timeout: 8))
    older.tap()

    XCTAssertTrue(app.staticTexts["BUILD SUMMARY"].waitForExistence(timeout: 8))
    XCTAssertFalse(app.buttons["physique.reassess"].exists)
  }
}
