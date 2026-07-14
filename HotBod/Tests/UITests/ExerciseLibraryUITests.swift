import XCTest

final class ExerciseLibraryUITests: BaseUITestCase {
  override func setUpWithError() throws {
    launchTab = "train"
    try super.setUpWithError()
  }

  func testBrowseExercisesOpensLibrary() {
    XCTAssertTrue(app.staticTexts["Train"].waitForExistence(timeout: 10))
    scrollIntoView(app.buttons["train.browseExercises"], maxSwipes: 10)
    tapButton("train.browseExercises", label: "Browse Exercises", timeout: 12)
    XCTAssertTrue(app.staticTexts["Exercise Library"].waitForExistence(timeout: 8))
  }

  func testLibrarySearchFiltersResults() {
    openLibrary()
    let searchField = app.textFields["library.search"]
    XCTAssertTrue(searchField.waitForExistence(timeout: 8))
    searchField.tap()
    searchField.typeText("press")

    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library.row.'")).firstMatch
        .waitForExistence(timeout: 8)
    )
  }

  func testLibraryOpensExerciseDetail() {
    openLibrary()
    let firstRow = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH 'library.row.'")
    ).firstMatch
    XCTAssertTrue(firstRow.waitForExistence(timeout: 10))
    tapElement(firstRow)
    XCTAssertTrue(app.navigationBars.element(boundBy: 0).waitForExistence(timeout: 8))
  }

  // MARK: - Helpers

  private func openLibrary() {
    XCTAssertTrue(app.otherElements["train.root"].waitForExistence(timeout: 10))
    scrollIntoView(app.buttons["train.browseExercises"], maxSwipes: 10)
    tapButton("train.browseExercises", label: "Browse Exercises", timeout: 12)
    XCTAssertTrue(app.staticTexts["Exercise Library"].waitForExistence(timeout: 8))
  }
}
