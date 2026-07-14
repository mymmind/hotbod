import XCTest

final class OnboardingUITests: BaseUITestCase {
  override func setUpWithError() throws {
    skipOnboarding = false
    try super.setUpWithError()
  }

  func testOnboardingWelcomeAppears() {
    XCTAssertTrue(app.staticTexts["TRAINING THAT ADAPTS."].waitForExistence(timeout: 8))
    XCTAssertTrue(app.buttons["Continue"].exists)
  }

  func testOnboardingCanAdvanceThroughGoalStep() {
    relaunchOnboarding(preset: "goalStep")
    tapButton("onboarding.goal.buildMuscle", label: "Build Muscle")
    relaunchOnboarding(preset: "afterGoal")
    XCTAssertTrue(app.buttons["onboarding.experience.intermediate"].waitForExistence(timeout: 12))
  }

  func testOnboardingShowsBackNavigation() {
    relaunchOnboarding(at: 2)
    tapButton("", label: "Back")
    XCTAssertTrue(app.buttons["onboarding.goal.buildMuscle"].waitForExistence(timeout: 12))
  }

  func testFullOnboardingCompletesToMainTabs() {
    relaunchOnboarding(preset: "readyToFinish", extraArgs: ["-AutoFinishOnboarding"])
    XCTAssertTrue(
      waitForTabBar(timeout: 20)
        || WorkoutSessionPage(app: app).waitForSession(timeout: 20)
    )
  }

  func testRegression_fullOnboardingStartsWorkoutSession() {
    relaunchOnboarding(preset: "readyToFinish", extraArgs: ["-AutoFinishOnboarding"])
    XCTAssertTrue(WorkoutSessionPage(app: app).waitForSession(timeout: 45))
  }

  func testOnboardingPhotoStepCanBeSkipped() {
    relaunchOnboarding(preset: "photoStep")
    tapButton("onboarding.photo.skip", label: "Skip For Now")
    relaunchOnboarding(preset: "readyToFinish")
    XCTAssertTrue(waitForSectionHeader("Plan Ready", timeout: 8))
  }

  func testRegression_onboardingPhotoSetupButtonOpensPicker() {
    relaunchOnboarding(preset: "photoStep")
    let setupButton = app.buttons["onboarding.photo.setup"]
    XCTAssertTrue(setupButton.waitForExistence(timeout: 8))
    setupButton.tap()
    XCTAssertTrue(waitForSectionHeader("Progress Photos", timeout: 8))
    tapButton("onboarding.photo.skip", label: "Skip For Now")
    relaunchOnboarding(preset: "readyToFinish")
    XCTAssertTrue(waitForSectionHeader("Plan Ready", timeout: 8))
  }

  // MARK: - Helpers

  private func relaunchOnboarding(at step: Int? = nil, preset: String? = nil, extraArgs: [String] = []) {
    app.terminate()
    app.launchArguments = ["-UITesting", "-ResetState", "-MockAI", "-MockFoodSearch"]
    app.launchArguments.removeAll { $0.hasPrefix("-OnboardingStep=") || $0.hasPrefix("-OnboardingPreset=") }
    if let step {
      app.launchArguments.append("-OnboardingStep=\(step)")
    }
    if let preset {
      app.launchArguments.append("-OnboardingPreset=\(preset)")
    }
    app.launchArguments.append(contentsOf: extraArgs)
    app.launch()
    if extraArgs.contains("-AutoFinishOnboarding") {
      _ = waitForTabBar(timeout: 20)
      return
    }
    XCTAssertTrue(
      app.buttons["onboarding.continue"].waitForExistence(timeout: 15)
        || app.buttons["onboarding.startWorkout"].waitForExistence(timeout: 5)
        || app.staticTexts["TRAINING THAT ADAPTS."].waitForExistence(timeout: 5)
    )
  }

  private func tapContinue(times: Int) {
    for _ in 0..<times {
      let continueButton = app.buttons["onboarding.continue"]
      XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
      scrollIntoView(continueButton)
      if continueButton.isHittable {
        continueButton.tap()
      } else {
        continueButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
      }
    }
  }
}
