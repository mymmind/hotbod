import XCTest

final class ProteinTrackerUITests: BaseUITestCase {
  override func setUpWithError() throws {
    launchTab = "protein"
    try super.setUpWithError()
  }

  func testProteinTabShowsDailyHero() {
    XCTAssertTrue(app.staticTexts["Protein"].waitForExistence(timeout: 8))
    XCTAssertTrue(app.staticTexts["DAILY INTAKE"].waitForExistence(timeout: 5))
  }

  func testFastAddUpdatesTotal() {
    tapButton("protein.add20g", label: "+20g")
    XCTAssertTrue(
      app.otherElements["protein.hero"].staticTexts.matching(NSPredicate(format: "label CONTAINS '20'")).firstMatch
        .waitForExistence(timeout: 8)
        || app.staticTexts.matching(NSPredicate(format: "label CONTAINS '20 /'")).firstMatch.waitForExistence(timeout: 2)
    )
  }

  func testCustomEntrySheetOpens() {
    tapButton("protein.custom", label: "Custom")
    XCTAssertTrue(app.navigationBars["Custom Entry"].waitForExistence(timeout: 8))
    app.buttons["Cancel"].tap()
  }

  func testWeeklyChartSectionExists() {
    XCTAssertTrue(waitForSectionHeader("Weekly"))
  }

  func testMultipleFastAddsAccumulate() {
    tapButton("protein.add10g", label: "+10g")
    tapButton("protein.add10g", label: "+10g")
    XCTAssertTrue(
      app.otherElements["protein.hero"].staticTexts.matching(NSPredicate(format: "label CONTAINS '20'")).firstMatch
        .waitForExistence(timeout: 8)
        || app.staticTexts.matching(NSPredicate(format: "label CONTAINS '20 /'")).firstMatch.waitForExistence(timeout: 2)
    )
  }
}
