import XCTest

struct TodayPage {
  let app: XCUIApplication

  var startWorkoutButton: XCUIElement { app.buttons["today.startWorkout"] }
  var resumeWorkoutButton: XCUIElement { app.buttons["today.resumeWorkout"] }
  var regenerateButton: XCUIElement { app.buttons["today.regenerate"] }
  var previewButton: XCUIElement { app.buttons["today.preview"] }
  var switchFocusButton: XCUIElement { app.buttons["today.switchFocus"] }
  var trainAnywayButton: XCUIElement { app.buttons["today.trainAnyway"] }
  var settingsButton: XCUIElement { app.buttons["today.settings"] }
  var askCoachButton: XCUIElement { app.buttons["Ask Coach"] }

  func waitForHero(timeout: TimeInterval = 8) -> Bool {
    startWorkoutButton.waitForExistence(timeout: timeout)
      || resumeWorkoutButton.waitForExistence(timeout: 1)
      || app.staticTexts["Recovery"].waitForExistence(timeout: 1)
      || app.staticTexts["No workout yet"].waitForExistence(timeout: 1)
  }
}

struct WorkoutSessionPage {
  let app: XCUIApplication

  var completeSetButton: XCUIElement {
    let byId = app.buttons["session.completeSet"]
    if byId.exists { return byId }
    return app.buttons["Complete Set"]
  }
  var skipExerciseButton: XCUIElement {
    let byId = app.buttons["session.skipExercise"]
    if byId.exists { return byId }
    return app.buttons["Skip"]
  }

  var swapExerciseButton: XCUIElement {
    let byId = app.buttons["session.swapExercise"]
    if byId.exists { return byId }
    return app.buttons["Swap"]
  }

  var previousExerciseButton: XCUIElement {
    let byId = app.buttons["session.previousExercise"]
    if byId.exists { return byId }
    return app.buttons["Previous exercise"]
  }

  var nextExerciseButton: XCUIElement {
    let byId = app.buttons["session.nextExercise"]
    if byId.exists { return byId }
    return app.buttons["Next exercise"]
  }
  var finishWorkoutButton: XCUIElement { app.buttons["session.finishWorkout"] }
  var workoutMenuButton: XCUIElement { app.buttons["session.workoutMenu"] }

  func waitForSession(timeout: TimeInterval = 10) -> Bool {
    if completeSetButton.waitForExistence(timeout: timeout) { return true }
    if app.otherElements["uitest.session.ready"].waitForExistence(timeout: 3) {
      return completeSetButton.waitForExistence(timeout: timeout)
    }
    let loading = app.otherElements["session.loading"]
    if loading.waitForExistence(timeout: 2) {
      _ = loading.waitForNonExistence(timeout: timeout)
    }
    return completeSetButton.waitForExistence(timeout: timeout)
  }

  func endWorkoutSavingProgress() {
    let endButton = app.buttons["session.ui.endWorkout"]
    if endButton.waitForExistence(timeout: 8) {
      if !endButton.isHittable { app.swipeUp() }
      endButton.tap()
      return
    }

    XCTAssertTrue(workoutMenuButton.waitForExistence(timeout: 8))
    workoutMenuButton.tap()

    let endCandidates = [
      app.buttons["session.menu.endWorkout"],
      app.menuItems["End Workout"],
      app.buttons["End Workout"],
      app.staticTexts["End Workout"]
    ]
    var tappedEnd = false
    for candidate in endCandidates {
      if candidate.waitForExistence(timeout: 2) {
        candidate.tap()
        tappedEnd = true
        break
      }
    }
    XCTAssertTrue(tappedEnd, "End Workout menu item not found")

    let saveCandidates = [
      app.buttons["session.endWorkout.save"],
      app.buttons["End & Save Progress"],
      app.alerts.buttons["End & Save Progress"],
      app.sheets.buttons["End & Save Progress"]
    ]
    var tappedSave = false
    for candidate in saveCandidates {
      if candidate.waitForExistence(timeout: 5) {
        candidate.tap()
        tappedSave = true
        break
      }
    }
    XCTAssertTrue(tappedSave, "End & Save Progress confirmation not found")
  }



}

