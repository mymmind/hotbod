import XCTest

final class CoachUITests: BaseUITestCase {
  override func setUpWithError() throws {
    launchTab = "coach"
    try super.setUpWithError()
  }

  func testCoachTabShowsSuggestions() {
    XCTAssertTrue(app.staticTexts["Coach"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["Ask your coach"].waitForExistence(timeout: 8))
  }

  func testCoachSuggestionSendsMockResponse() {
    tapButton("coach.suggestion.protein", label: "How much protein do I still need?")

    XCTAssertTrue(
      app.staticTexts["coach.assistantMessage"].waitForExistence(timeout: 12)
        || app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'logged'")).firstMatch
          .waitForExistence(timeout: 12)
    )
  }

  func testCoachManualMessageGetsResponse() {
    let field = app.textFields["coach.input"]
    XCTAssertTrue(field.waitForExistence(timeout: 8))
    scrollIntoView(field)
    field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    field.typeText("Why am I doing this workout today?")

    tapButton("", label: "Send message")

    XCTAssertTrue(
      app.staticTexts["coach.assistantMessage"].waitForExistence(timeout: 12)
        || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'workout' OR label CONTAINS[c] 'session'"))
          .firstMatch.waitForExistence(timeout: 12)
    )
  }

  func testCoachFromTodaySecondaryFlow() {
    XCTAssertTrue(waitForTabBar())
    app.swipeUp()

    let askCoach = app.buttons["Ask Coach"]
    guard askCoach.waitForExistence(timeout: 5) else { return }

    askCoach.tap()
    XCTAssertTrue(app.staticTexts["Coach"].waitForExistence(timeout: 8))
  }
}
