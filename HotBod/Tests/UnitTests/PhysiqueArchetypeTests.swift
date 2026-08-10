import XCTest
@testable import HotBod

final class PhysiqueArchetypeCatalogTests: XCTestCase {
    func testCatalogLoadsExpectedEntries() {
        let entries = PhysiqueArchetypeCatalogLoader.load()
        XCTAssertGreaterThanOrEqual(entries.count, 8)
        XCTAssertLessThanOrEqual(entries.count, 12)
        let ids = Set(entries.map(\.id))
        XCTAssertTrue(ids.contains("classic_athletic"))
        XCTAssertTrue(ids.contains("lean_fighter"))
        let classic = entries.first { $0.id == "classic_athletic" }
        XCTAssertEqual(classic?.genericLabel, "Classic athletic")
        XCTAssertNotNil(classic?.referenceLabel)
        let mens = entries.first { $0.id == "mens_physique" }
        XCTAssertNil(mens?.referenceLabel)
    }

    func testPhysiqueAssessmentDecodesMissingDirectionsAsEmpty() throws {
        var assessment = FixtureBuilders.makePhysiqueAssessment()
        assessment.physiqueDirections = [
            PhysiqueArchetypeMatch(
                archetypeId: "classic_athletic",
                rank: 1,
                similarityDimension: "Lean silhouette",
                confidence: .medium
            )
        ]
        let encoded = try JSONEncoder().encode(assessment)
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            return XCTFail("Expected encoded assessment to be a JSON object")
        }
        object.removeValue(forKey: "physiqueDirections")
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(PhysiqueAssessment.self, from: stripped)
        XCTAssertEqual(decoded.physiqueDirections, [])
    }
}
