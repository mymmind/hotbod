import XCTest

final class PhysiqueCadenceUITests: BaseUITestCase {
  override func setUpWithError() throws {
    seedPhysiqueCadenceDue = true
    launchTab = "physique"
    try super.setUpWithError()
  }

  func testCadenceDueBannerAppearsWhenAssessmentOverdue() {
    XCTAssertTrue(app.otherElements["physique.root"].waitForExistence(timeout: 15))
    XCTAssertTrue(
      app.staticTexts["physique.cadenceDue"].waitForExistence(timeout: 10)
        || app.descendants(matching: .any)["physique.cadenceDue"].waitForExistence(timeout: 5)
    )
  }
}

final class PhysiqueCadenceFreshUITests: BaseUITestCase {
  override func setUpWithError() throws {
    launchTab = "physique"
    try super.setUpWithError()
  }

  func testFreshAssessmentHasNoCadenceDueBanner() {
    XCTAssertTrue(app.otherElements["physique.root"].waitForExistence(timeout: 15))
    XCTAssertFalse(app.descendants(matching: .any)["physique.cadenceDue"].waitForExistence(timeout: 3))
  }
}
