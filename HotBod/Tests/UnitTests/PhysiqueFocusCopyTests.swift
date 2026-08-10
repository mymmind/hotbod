import XCTest
@testable import HotBod

final class PhysiqueFocusCopyTests: XCTestCase {
    func testTodayBiasLineListsTopPriorities() {
        let assessment = FixtureBuilders.makePhysiqueAssessment()
        let line = PhysiqueFocusCopy.todayBiasLine(from: assessment)
        XCTAssertTrue(line.hasPrefix("Focus bias:"))
        XCTAssertTrue(
            line.contains("Lateral Delts")
                || line.contains("Lateral delts")
                || line.localizedCaseInsensitiveContains("lateral")
        )
    }

    func testTodayBiasLineRespectsLimit() {
        let assessment = FixtureBuilders.makePhysiqueAssessment()
        let line = PhysiqueFocusCopy.todayBiasLine(from: assessment, limit: 2)
        XCTAssertEqual(line, "Focus bias: Lateral Delts, Lats")
    }
}
