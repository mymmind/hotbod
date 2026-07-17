import XCTest

final class BodyProgressUITests: BaseUITestCase {
  override func setUpWithError() throws {
    launchTab = "progress"
    try super.setUpWithError()
  }

  func testProgressTabShowsDashboard() {
    XCTAssertTrue(app.staticTexts["Progress"].waitForExistence(timeout: 10))
    XCTAssertTrue(waitForSectionHeader("Compliance", timeout: 15))
  }

  func testBodyProgressNavigationOpens() {
    app.swipeUp()

    let link = app.buttons["progress.bodyProgressLink"]
    XCTAssertTrue(link.waitForExistence(timeout: 10))
    scrollIntoView(link)
    tapElement(link)

    XCTAssertTrue(app.navigationBars["Body Progress"].waitForExistence(timeout: 8))
    XCTAssertTrue(app.buttons["bodyProgress.addPhoto"].waitForExistence(timeout: 5))
  }

  func testBodyProgressEmptyTimelineMessage() {
    openBodyProgress()
    XCTAssertTrue(
      app.staticTexts["No photos yet. Import your first progress photo."].waitForExistence(timeout: 8)
    )
  }

  func testAddPhotoShowsCameraAndLibraryActions() {
    openBodyProgress()
    let addPhoto = app.buttons["bodyProgress.addPhoto"]
    XCTAssertTrue(addPhoto.waitForExistence(timeout: 5))
    tapElement(addPhoto)

    XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Choose from Library"].waitForExistence(timeout: 2))
  }

  // MARK: - Helpers

  private func openBodyProgress() {
    let link = app.buttons["progress.bodyProgressLink"]
    XCTAssertTrue(link.waitForExistence(timeout: 8))
    scrollIntoView(link)
    tapElement(link)
    XCTAssertTrue(app.navigationBars["Body Progress"].waitForExistence(timeout: 8))
  }
}
