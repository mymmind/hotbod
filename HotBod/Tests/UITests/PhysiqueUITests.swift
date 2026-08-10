import XCTest

final class PhysiqueUITests: BaseUITestCase {
  override func setUpWithError() throws {
    launchTab = "physique"
    try super.setUpWithError()
  }

  func testPhysiqueTabEmptyState() {
    XCTAssertTrue(app.otherElements["physique.root"].waitForExistence(timeout: 10)
      || app.staticTexts["Physique"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      app.staticTexts["Add front and back photos to get a focus plan."].waitForExistence(timeout: 8)
    )
    XCTAssertFalse(app.staticTexts["Ask your coach"].exists)
  }
}
