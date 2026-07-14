import XCTest

final class LaunchUITests: BaseUITestCase {
  func testAppLaunchesToMainTabs() {
    XCTAssertTrue(waitForTabBar())
    XCTAssertTrue(app.buttons["tab.today"].exists)
    XCTAssertTrue(app.buttons["tab.train"].exists)
    XCTAssertTrue(app.buttons["tab.protein"].exists)
    XCTAssertTrue(app.buttons["tab.progress"].exists)
  }

  func testTodayTabShowsHero() {
    XCTAssertTrue(waitForTabBar())
    app.buttons["tab.today"].tap()
    XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 5))
  }

  func testTrainTabOpens() {
    XCTAssertTrue(waitForTabBar())
    app.buttons["tab.train"].tap()
    XCTAssertTrue(app.staticTexts["Train"].waitForExistence(timeout: 5))
  }
}
