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

final class PhysiqueArchetypeMatcherTests: XCTestCase {
    func testFavorableVTaperSignalsPreferClassicOrVTaperIds() {
        let physique = PhysiqueBuildSummary(
            overallArchetype: "Athletic build with favorable shoulder-to-waist contrast",
            frameSize: "Medium",
            shoulderToWaist: "Favorable contrast",
            waist: "Relatively narrow",
            torso: "Medium",
            muscularity: "Moderate",
            leanness: "Moderately lean"
        )
        let priorities = [
            PhysiqueDevelopmentPriority(muscle: .lateralDelts, reason: "Width"),
            PhysiqueDevelopmentPriority(muscle: .lats, reason: "Taper")
        ]
        let matches = PhysiqueArchetypeMatcher.match(
            physique: physique,
            priorities: priorities,
            overallConfidence: 0.8
        )
        XCTAssertFalse(matches.isEmpty)
        XCTAssertLessThanOrEqual(matches.count, 3)
        let ids = matches.map(\.archetypeId)
        XCTAssertTrue(
            ids.contains("classic_athletic") || ids.contains("v_taper_focus") || ids.contains("mens_physique")
        )
        XCTAssertEqual(matches.map(\.rank), Array(1...matches.count))
    }

    func testLowConfidenceReturnsAtMostOneMatch() {
        let assessment = FixtureBuilders.makePhysiqueAssessment()
        let matches = PhysiqueArchetypeMatcher.match(
            physique: assessment.physique,
            priorities: assessment.developmentPriorities,
            overallConfidence: 0.4
        )
        XCTAssertLessThanOrEqual(matches.count, 1)
    }
}

final class PhysiqueArchetypeSanitizerTests: XCTestCase {
    func testDropsUnknownIdsCapsAndFallsBackWhenEmpty() {
        let catalogIds = Set(PhysiqueArchetypeCatalogLoader.load().map(\.id))
        let assessment = FixtureBuilders.makePhysiqueAssessment()
        let cleaned = PhysiqueAssessmentSanitizer.sanitizeDirections(
            [
                .init(archetypeId: "not_real", rank: 1, similarityDimension: "x", confidenceRaw: "high"),
                .init(
                    archetypeId: "classic_athletic",
                    rank: 2,
                    similarityDimension: "Lean silhouette",
                    confidenceRaw: "medium"
                ),
                .init(
                    archetypeId: "lean_fighter",
                    rank: 3,
                    similarityDimension: "you look like a twin",
                    confidenceRaw: "medium"
                ),
                .init(
                    archetypeId: "mens_physique",
                    rank: 4,
                    similarityDimension: "V-taper direction",
                    confidenceRaw: "low"
                )
            ],
            catalogIds: catalogIds,
            physique: assessment.physique,
            priorities: assessment.developmentPriorities,
            overallConfidence: assessment.photoQuality.overallConfidence
        )
        XCTAssertEqual(cleaned.count, 3)
        XCTAssertFalse(cleaned.contains { $0.archetypeId == "not_real" })
        XCTAssertFalse(cleaned.contains { $0.similarityDimension.localizedCaseInsensitiveContains("look like") })
        XCTAssertEqual(cleaned.map(\.rank), [1, 2, 3])

        let fallback = PhysiqueAssessmentSanitizer.sanitizeDirections(
            [],
            catalogIds: catalogIds,
            physique: assessment.physique,
            priorities: assessment.developmentPriorities,
            overallConfidence: 0.8
        )
        XCTAssertFalse(fallback.isEmpty)
    }
}
