import XCTest

final class PhysiqueIllustrationUITests: BaseUITestCase {
  override func setUpWithError() throws {
    launchTab = "physique"
    seedPhysiqueIllustrationReady = true
    try super.setUpWithError()
  }

  func testGenerateIllustrativeDirectionShowsResult() {
    let generate = app.buttons["physique.illustrate"]
    XCTAssertTrue(generate.waitForExistence(timeout: 10))
    generate.tap()
    XCTAssertTrue(
      app.otherElements["physique.illustrate.result"].waitForExistence(timeout: 10)
        || app.descendants(matching: .any)["physique.illustrate.result"].waitForExistence(timeout: 10)
    )
    XCTAssertTrue(
      app.staticTexts[
        "This is an illustration of possible emphasis — not a forecast of your body, timeline, or genetics."
      ].waitForExistence(timeout: 5)
    )
  }
}
