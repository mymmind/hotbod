import XCTest

final class PhysiqueSplitSuggestionUITests: BaseUITestCase {
    override func setUpWithError() throws {
        seedPhysiqueSplitSuggestion = true
        launchTab = "physique"
        try super.setUpWithError()
    }

    func testSplitSuggestionCardAppearsWhenSeeded() {
        XCTAssertTrue(app.otherElements["physique.root"].waitForExistence(timeout: 15))
        XCTAssertTrue(
            app.descendants(matching: .any)["physique.splitSuggestion"].waitForExistence(timeout: 10)
        )
    }
}
