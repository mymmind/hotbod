import XCTest

final class TodayWorkoutUITests: BaseUITestCase {
  private var today: TodayPage { TodayPage(app: app) }

  override func setUpWithError() throws {
    if name.contains("Preview") {
      openWorkoutPreviewOnLaunch = true
    }
    try super.setUpWithError()
  }

  func testTodayShowsWorkoutHero() {
    XCTAssertTrue(waitForTabBar())
    XCTAssertTrue(today.waitForHero())
  }

  func testStartWorkoutOpensSession() {
    app.terminate()
    app.launchArguments.append("-StartWorkout")
    app.launch()
    XCTAssertTrue(WorkoutSessionPage(app: app).waitForSession(timeout: 45))
  }

  func testRegenerateWorkoutStillShowsHero() {
    XCTAssertTrue(waitForTabBar())
    XCTAssertTrue(today.waitForHero())

    guard today.regenerateButton.waitForExistence(timeout: 5) else {
      return // rest day or completed session
    }

    today.regenerateButton.tap()
    XCTAssertTrue(today.waitForHero(timeout: 15))
  }

  func testRegression_trainAnywayReplacesRestHeroWithPlan() {
    app.terminate()
    app.launchArguments.append("-ForceRestDay")
    app.launch()
    XCTAssertTrue(waitForTabBar())

    tapButton("today.trainAnyway", label: "Train Anyway")
    XCTAssertTrue(app.buttons["today.startWorkout"].waitForExistence(timeout: 20))
  }

  func testPreviewOpensWorkoutPreview() {
    XCTAssertTrue(app.staticTexts["Preview"].waitForExistence(timeout: 8))
    XCTAssertTrue(
      app.buttons["Start Workout"].waitForExistence(timeout: 5)
        || app.buttons["Resume Workout"].waitForExistence(timeout: 2)
    )
  }

  func testPreviewSwapOpensAlternatives() {
    XCTAssertTrue(app.staticTexts["Preview"].waitForExistence(timeout: 8))

    let swapButton = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH 'preview.swap.'")
    ).firstMatch
    XCTAssertTrue(swapButton.waitForExistence(timeout: 5), "Expected preview swap button")
    scrollIntoView(swapButton)
    swapButton.tap()

    XCTAssertTrue(
      app.staticTexts["Swap Exercise"].waitForExistence(timeout: 5)
        || app.staticTexts["ALTERNATIVES"].waitForExistence(timeout: 5)
    )
  }

  func testPreviewExerciseRowOpensSetDetail() {
    XCTAssertTrue(app.staticTexts["Preview"].waitForExistence(timeout: 8))

    let exerciseRow = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH 'preview.exerciseRow.'")
    ).firstMatch
    XCTAssertTrue(exerciseRow.waitForExistence(timeout: 5), "Expected preview exercise row")
    scrollIntoView(exerciseRow)
    exerciseRow.tap()

    XCTAssertTrue(app.staticTexts["PLANNED SETS"].waitForExistence(timeout: 5))
  }

  func testSettingsOpensFromToday() {
    tapButton("today.settings", label: "Settings")
    XCTAssertTrue(waitForSettings(timeout: 12))
    tapButton("settings.done", label: "Done")
  }

  func testAskCoachNavigatesToCoach() {
    XCTAssertTrue(waitForTabBar())
    app.swipeUp()

    guard today.askCoachButton.waitForExistence(timeout: 5) else { return }

    today.askCoachButton.tap()
    XCTAssertTrue(app.staticTexts["Coach"].waitForExistence(timeout: 8))
  }
}
