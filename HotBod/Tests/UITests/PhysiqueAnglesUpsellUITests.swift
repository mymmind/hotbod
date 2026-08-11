import XCTest

final class PhysiqueAnglesUpsellUITests: BaseUITestCase {
  override func setUpWithError() throws {
    launchTab = "physique"
    seedPhysiqueFrontOnly = true
    try super.setUpWithError()
  }

  func testAnglesUpsellVisibleForFrontOnlyAssessment() {
    XCTAssertTrue(
      app.descendants(matching: .any)["physique.anglesUpsell"].waitForExistence(timeout: 10)
    )
  }
}

final class PhysiqueAnglesUpsellHiddenUITests: BaseUITestCase {
  override func setUpWithError() throws {
    launchTab = "physique"
    seedPhysiqueHistory = true // seed stubs front+back+side so upsell can hide
    try super.setUpWithError()
  }

  func testAnglesUpsellHiddenWhenBackPresent() {
    XCTAssertFalse(
      app.descendants(matching: .any)["physique.anglesUpsell"].waitForExistence(timeout: 3)
    )
  }
}
