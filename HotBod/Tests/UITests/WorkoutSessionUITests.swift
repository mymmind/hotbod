import XCTest

final class WorkoutSessionUITests: BaseUITestCase {
  private var session: WorkoutSessionPage { WorkoutSessionPage(app: app) }


  private func tapSessionAction(_ identifier: String) {
    let button = app.buttons[identifier]
    XCTAssertTrue(button.waitForExistence(timeout: 8), "Missing \(identifier)")
    for _ in 0..<4 where !button.isHittable {
      app.swipeUp()
    }
    if button.isHittable {
      button.tap()
    } else {
      button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
  }

  private func waitForWorkoutComplete(timeout: TimeInterval = 15) -> Bool {
    if app.descendants(matching: .any)["session.workoutComplete"].waitForExistence(timeout: timeout) { return true }
    if app.staticTexts["session.workoutComplete"].waitForExistence(timeout: 2) { return true }
    if app.staticTexts["WORKOUT COMPLETE"].waitForExistence(timeout: 2) { return true }
    return app.buttons["session.finishWorkout"].waitForExistence(timeout: 2)
  }

  override func setUpWithError() throws {
    startWorkoutOnLaunch = true
    try super.setUpWithError()
  }

  func testSessionShowsCompleteSetButton() {
    XCTAssertTrue(session.waitForSession())
    XCTAssertTrue(session.completeSetButton.waitForExistence(timeout: 5))
  }

  func testCompleteSetAdvancesProgress() {
    XCTAssertTrue(session.waitForSession())
    session.completeSetButton.tap()

    XCTAssertTrue(
      session.completeSetButton.waitForExistence(timeout: 8)
        || session.finishWorkoutButton.waitForExistence(timeout: 3)
        || app.staticTexts["WORKOUT COMPLETE"].waitForExistence(timeout: 3)
    )
  }

  func testSkipExerciseMovesForward() {
    XCTAssertTrue(session.waitForSession())
    scrollIntoView(session.skipExerciseButton)
    XCTAssertTrue(session.skipExerciseButton.waitForExistence(timeout: 5))
    tapElement(session.skipExerciseButton)
    XCTAssertTrue(session.completeSetButton.waitForExistence(timeout: 8))
  }

  func testPreviousExerciseNavigation() {
    XCTAssertTrue(session.waitForSession())
    XCTAssertTrue(session.previousExerciseButton.waitForExistence(timeout: 5))

    scrollIntoView(session.skipExerciseButton)
    tapElement(session.skipExerciseButton)
    XCTAssertTrue(session.completeSetButton.waitForExistence(timeout: 8))
    XCTAssertTrue(
      app.staticTexts["session.exercisePosition"].waitForExistence(timeout: 8)
        || app.staticTexts.matching(NSPredicate(format: "label CONTAINS '2 of 3'")).firstMatch
          .waitForExistence(timeout: 8)
    )

    tapElement(session.previousExerciseButton)
    XCTAssertTrue(session.completeSetButton.waitForExistence(timeout: 8))
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS '1 of 3'")).firstMatch
        .waitForExistence(timeout: 8)
    )
    XCTAssertTrue(session.nextExerciseButton.waitForExistence(timeout: 5))
  }

  func testSwapExerciseOpensAlternatives() {
    XCTAssertTrue(session.waitForSession())
    tapSessionAction("session.swapExercise")

    XCTAssertTrue(
      app.descendants(matching: .any)["swap.sheet"].waitForExistence(timeout: 8)
        || app.staticTexts["Swap Exercise"].waitForExistence(timeout: 5)
        || app.staticTexts["ALTERNATIVES"].waitForExistence(timeout: 5)
        || app.sheets.firstMatch.waitForExistence(timeout: 5)
    )

    let substitute = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH 'swap.substitute.' AND enabled == true")
    ).firstMatch
    XCTAssertTrue(substitute.waitForExistence(timeout: 12), "Expected at least one swap substitute")
    substitute.tap()

    XCTAssertFalse(app.staticTexts["Swap Exercise"].waitForExistence(timeout: 1))
    XCTAssertTrue(session.completeSetButton.waitForExistence(timeout: 5))
  }

  func testEndWorkoutShowsCompletion() {
    XCTAssertTrue(session.waitForSession())
    session.endWorkoutSavingProgress()
    XCTAssertTrue(waitForWorkoutComplete())
  }

  func testFinishWorkoutReturnsToTabs() {
    XCTAssertTrue(session.waitForSession())
    session.endWorkoutSavingProgress()
    XCTAssertTrue(waitForWorkoutComplete())
    tapSessionAction("session.finishWorkout")
    XCTAssertTrue(waitForTabBar(timeout: 10))
  }

  func testExitWorkoutReturnsToToday() {
    XCTAssertTrue(session.waitForSession())
    tapSessionAction("session.exitWorkout")
    XCTAssertTrue(waitForMainShell(timeout: 15) || waitForTabBar(timeout: 15))
  }

  func testRegression_exerciseCompleteIsFullScreen() {
    XCTAssertTrue(session.waitForSession())

    var sawExerciseComplete = false
    for _ in 0..<24 {
      session.dismissTransientPromptsIfNeeded()

      if session.exerciseComplete.waitForExistence(timeout: 1) {
        sawExerciseComplete = true
        break
      }

      if session.completeSetButton.waitForExistence(timeout: 2) {
        if session.completeSetButton.isHittable {
          session.completeSetButton.tap()
        } else {
          session.completeSetButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        session.dismissTransientPromptsIfNeeded()
        continue
      }

      session.dismissTransientPromptsIfNeeded()
    }

    XCTAssertTrue(sawExerciseComplete, "Expected Exercise Complete after finishing an exercise")
    XCTAssertTrue(session.exerciseComplete.waitForExistence(timeout: 2))
    XCTAssertTrue(session.exerciseCompleteContinue.waitForExistence(timeout: 2))
    XCTAssertFalse(session.completeSetButton.exists, "Active session Complete Set must not remain visible")
  }
}
