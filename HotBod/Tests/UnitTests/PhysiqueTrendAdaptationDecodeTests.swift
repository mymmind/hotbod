import XCTest
@testable import HotBod

final class PhysiqueTrendAdaptationDecodeTests: XCTestCase {
    func testPhysiqueAssessmentDecodesMissingTrendAdaptationAsNil() throws {
        var assessment = FixtureBuilders.makePhysiqueAssessment()
        assessment.trendAdaptation = nil
        let data = try JSONEncoder().encode(assessment)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return XCTFail("Expected encoded assessment to be a JSON object")
        }
        object.removeValue(forKey: "trendAdaptation")
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(PhysiqueAssessment.self, from: stripped)
        XCTAssertNil(decoded.trendAdaptation)
    }

    func testPhysiqueAssessmentRoundTripsTrendAdaptation() throws {
        var assessment = FixtureBuilders.makePhysiqueAssessment()
        let previousId = UUID()
        assessment.trendAdaptation = PhysiqueTrendAdaptation(
            previousAssessmentId: previousId,
            reasons: ["Lats emphasized — priority appeared since last."]
        )
        let data = try JSONEncoder().encode(assessment)
        let decoded = try JSONDecoder().decode(PhysiqueAssessment.self, from: data)
        XCTAssertEqual(decoded.trendAdaptation?.previousAssessmentId, previousId)
        XCTAssertEqual(decoded.trendAdaptation?.reasons.count, 1)
    }
}
