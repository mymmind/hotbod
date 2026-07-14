import XCTest

final class SettingsUITests: BaseUITestCase {
  override func setUpWithError() throws {
    openSettingsOnLaunch = !name.contains("testSettingsOpensFromToday")
    try super.setUpWithError()
  }

  func testSettingsOpensFromToday() {
    tapButton("today.settings", label: "Settings")
    XCTAssertTrue(waitForSettings(timeout: 12))
  }

  func testSettingsShowsTrainingSection() {
    openSettings()
    XCTAssertTrue(waitForSectionHeader("Training"))
    XCTAssertTrue(waitForSectionHeader("Goal"))
  }

  func testSettingsShowsProteinSection() {
    openSettings()
    app.swipeUp()
    XCTAssertTrue(waitForSectionHeader("Protein"))
  }

  func testSettingsDismissesWithDone() {
    openSettings()
    tapButton("settings.done", label: "Done")
    XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 8))
  }

  func testEquipmentPickerOpens() {
    openSettings()
    app.swipeUp()
    tapButton("settings.equipment.row")
    XCTAssertTrue(app.navigationBars["Equipment"].waitForExistence(timeout: 8))
  }

  func testWarmupToggleExists() {
    openSettings()
    XCTAssertTrue(
      app.staticTexts["Warm-up sets"].waitForExistence(timeout: 3)
        || app.staticTexts["WARM-UP SETS"].waitForExistence(timeout: 3)
    )
  }

  func testDeleteAllDataShowsConfirmation() {
    openSettings()
    scrollToDeleteAllData()
    tapButton("settings.deleteAllData", label: "Delete All Data")
    XCTAssertTrue(app.buttons["Delete All Data"].waitForExistence(timeout: 5))
  }

  // MARK: - Helpers

  private func scrollToDeleteAllData() {
    let deleteButton = app.buttons["settings.deleteAllData"]
    for _ in 0..<6 where !deleteButton.exists {
      app.swipeUp()
    }
    XCTAssertTrue(deleteButton.waitForExistence(timeout: 8))
  }

  private func openSettings() {
    if waitForSettings(timeout: 2) { return }
    tapButton("today.settings", label: "Settings")
    XCTAssertTrue(waitForSettings(timeout: 12))
  }
}
