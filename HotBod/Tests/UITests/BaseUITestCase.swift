import XCTest

class BaseUITestCase: XCTestCase {
  var app: XCUIApplication!
  var skipOnboarding = true
  var openSettingsOnLaunch = false
  var startWorkoutOnLaunch = false
  var openWorkoutPreviewOnLaunch = false
  var launchTab: String?
  var onboardingStartStep: Int?

  private let tabOrder = ["today", "train", "protein", "progress", "coach"]

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["-UITesting", "-ResetState", "-MockAI", "-MockFoodSearch"]
    if skipOnboarding {
      app.launchArguments.append("-SkipOnboarding")
    }
    if openSettingsOnLaunch {
      app.launchArguments.append("-OpenSettings")
    }
    if startWorkoutOnLaunch {
      app.launchArguments.append("-StartWorkout")
    }
    if openWorkoutPreviewOnLaunch {
      app.launchArguments.append("-OpenWorkoutPreview")
    }
    if let launchTab {
      app.launchArguments.append("-OpenTab=\(launchTab)")
    }
    if let onboardingStartStep {
      app.launchArguments.append("-OnboardingStep=\(onboardingStartStep)")
    }
    app.launch()

    if skipOnboarding {
      if startWorkoutOnLaunch {
        XCTAssertTrue(WorkoutSessionPage(app: app).waitForSession(timeout: 60))
        return
      }
      if openWorkoutPreviewOnLaunch {
        XCTAssertTrue(
          app.staticTexts["Preview"].waitForExistence(timeout: 20)
            || app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'preview.exerciseRow.'")).firstMatch
              .waitForExistence(timeout: 5)
        )
        return
      }
      if openSettingsOnLaunch {
        XCTAssertTrue(waitForSettings(timeout: 20))
        return
      }
      if let launchTab {
        XCTAssertTrue(waitForTabBar(timeout: 15))
        XCTAssertTrue(waitForTabContent(launchTab, timeout: 20), "Launch tab \(launchTab) did not appear")
        return
      }
      XCTAssertTrue(waitForTabBar(timeout: 15))
      XCTAssertTrue(waitForMainShell(timeout: 20))
      _ = waitForTodayWorkoutReady(timeout: 25)
    } else {
      XCTAssertTrue(
        app.staticTexts["TRAINING THAT ADAPTS."].waitForExistence(timeout: 15)
          || app.buttons["onboarding.goal.buildMuscle"].waitForExistence(timeout: 2),
        "Onboarding did not appear"
      )
    }
  }

  func waitForTabBar(timeout: TimeInterval = 12) -> Bool {
    app.buttons["tab.today"].waitForExistence(timeout: timeout)
  }

  func waitForMainShell(timeout: TimeInterval = 12) -> Bool {
    if app.buttons["today.startWorkout"].waitForExistence(timeout: timeout) { return true }
    if app.buttons["today.resumeWorkout"].waitForExistence(timeout: 2) { return true }
    if app.buttons["today.trainAnyway"].waitForExistence(timeout: 2) { return true }
    if app.buttons["today.settings"].waitForExistence(timeout: 2) { return true }
    if app.staticTexts["No workout yet"].waitForExistence(timeout: 2) { return true }
    if app.staticTexts["Recovery"].waitForExistence(timeout: 2) { return true }
    return false
  }

  func waitForTodayWorkoutReady(timeout: TimeInterval = 25) -> Bool {
    app.buttons["today.startWorkout"].waitForExistence(timeout: timeout)
      || app.buttons["today.resumeWorkout"].waitForExistence(timeout: 3)
      || app.buttons["today.trainAnyway"].waitForExistence(timeout: 3)
  }

  func tapTab(_ tab: String) {
    if waitForTabContent(tab, timeout: 1) { return }

    let button = app.buttons["tab.\(tab)"]
    XCTAssertTrue(button.waitForExistence(timeout: 8), "Missing tab.\(tab)")
    tapElement(button)

    if !waitForTabContent(tab, timeout: 4), let index = tabOrder.firstIndex(of: tab) {
      let normalizedX = (Double(index) + 0.5) / Double(tabOrder.count)
      let normalizedY = 0.94
      app.coordinate(withNormalizedOffset: CGVector(dx: normalizedX, dy: normalizedY)).tap()
    }

    XCTAssertTrue(waitForTabContent(tab, timeout: 12), "Tab \(tab) content did not appear")
  }

  func waitForTabContent(_ tab: String, timeout: TimeInterval = 12) -> Bool {
    switch tab {
    case "today":
      return waitForMainShell(timeout: timeout)
    case "train":
      return app.otherElements["train.root"].waitForExistence(timeout: timeout)
        || app.staticTexts["PROGRAM"].waitForExistence(timeout: 2)
    case "protein":
      return app.staticTexts["DAILY INTAKE"].waitForExistence(timeout: timeout)
        || app.buttons["protein.custom"].waitForExistence(timeout: 2)
    case "progress":
      return app.otherElements["progress.dashboard"].waitForExistence(timeout: timeout)
        || app.otherElements["progress.compliance"].waitForExistence(timeout: 2)
        || waitForSectionHeader("Compliance", timeout: 2)
    case "coach":
      return app.otherElements["coach.root"].waitForExistence(timeout: timeout)
        || app.staticTexts["Ask your coach"].waitForExistence(timeout: 2)
    default:
      return app.buttons["tab.\(tab)"].waitForExistence(timeout: timeout)
    }
  }

  func button(_ identifier: String, label: String? = nil, timeout: TimeInterval = 8) -> XCUIElement {
    if !identifier.isEmpty {
      let byId = app.buttons[identifier]
      if byId.waitForExistence(timeout: timeout) { return byId }
    }
    if let label {
      let byLabel = app.buttons[label]
      if byLabel.waitForExistence(timeout: timeout) { return byLabel }
    }
    if !identifier.isEmpty { return app.buttons[identifier] }
    return app.buttons[label ?? ""]
  }

  func tapButton(_ identifier: String, label: String? = nil, timeout: TimeInterval = 8) {
    let target = button(identifier, label: label, timeout: timeout)
    XCTAssertTrue(target.waitForExistence(timeout: timeout), "Missing button \(identifier)\(label.map { " (\($0))" } ?? "")")
    scrollIntoView(target)
    tapElement(target)
  }

  func tapStaticText(_ text: String, timeout: TimeInterval = 8) {
    let element = app.staticTexts[text]
    XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing text \(text)")
    tapElement(element)
  }

  func waitForStaticText(_ text: String, timeout: TimeInterval = 8) -> Bool {
    app.staticTexts[text].waitForExistence(timeout: timeout)
  }

  func waitForSettings(timeout: TimeInterval = 12) -> Bool {
    if app.staticTexts["Settings"].waitForExistence(timeout: timeout) { return true }
    if app.otherElements["settings.root"].waitForExistence(timeout: 2) { return true }
    return app.sheets.firstMatch.staticTexts["Settings"].waitForExistence(timeout: 3)
  }

  func waitForSectionHeader(_ title: String, timeout: TimeInterval = 8) -> Bool {
    if app.staticTexts[title.uppercased()].waitForExistence(timeout: timeout) { return true }
    if app.staticTexts[title].waitForExistence(timeout: 1) { return true }
    return app.otherElements.matching(
      NSPredicate(format: "label BEGINSWITH %@", title)
    ).firstMatch.waitForExistence(timeout: timeout)
  }

  func scrollIntoView(_ element: XCUIElement, maxSwipes: Int = 8) {
    guard element.exists else { return }
    for _ in 0..<maxSwipes where !element.isHittable {
      app.swipeUp()
    }
    for _ in 0..<maxSwipes where !element.isHittable {
      app.swipeDown()
    }
    let scrollView = app.scrollViews.firstMatch
    guard scrollView.exists else { return }
    for _ in 0..<maxSwipes where !element.isHittable {
      scrollView.swipeUp()
    }
    for _ in 0..<maxSwipes where !element.isHittable {
      scrollView.swipeDown()
    }
  }

  // MARK: - Tap helpers

  func tapElement(_ element: XCUIElement) {
    scrollIntoView(element)

    if element.isHittable {
      element.tap()
      return
    }

    if element.frame.width > 0, element.frame.height > 0 {
      element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
      return
    }

    if !identifier(for: element).isEmpty {
      let byId = app.buttons[identifier(for: element)]
      if byId.exists, byId.frame.width > 0, byId.frame.height > 0 {
        byId.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        return
      }
    }

    element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
  }

  private func identifier(for element: XCUIElement) -> String {
    element.identifier
  }
}
