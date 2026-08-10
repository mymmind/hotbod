import XCTest
@testable import HotBod

final class PhysiqueAssessmentDiffTests: XCTestCase {
    func testBuildFieldChangeAppearsInSummary() {
        var previous = FixtureBuilders.makePhysiqueAssessment()
        var current = FixtureBuilders.makePhysiqueAssessment()
        previous.physique.frameSize = "Medium"
        current.physique.frameSize = "Large"
        let diff = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
        XCTAssertTrue(diff.hasMeaningfulChange)
        XCTAssertTrue(diff.buildChanges.contains { $0.field == "Frame" && $0.from == "Medium" && $0.to == "Large" })
        XCTAssertTrue(diff.summaryLines.contains { $0.contains("Frame") && $0.contains("Medium") && $0.contains("Large") })
    }

    func testPriorityAddRemoveReorder() {
        var previous = FixtureBuilders.makePhysiqueAssessment()
        var current = FixtureBuilders.makePhysiqueAssessment()
        previous.developmentPriorities = [
            .init(muscle: .lateralDelts, reason: "a"),
            .init(muscle: .lats, reason: "b")
        ]
        current.developmentPriorities = [
            .init(muscle: .lats, reason: "b"),
            .init(muscle: .upperChest, reason: "c")
        ]
        let diff = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
        XCTAssertEqual(diff.priorityChanges.added, [.upperChest])
        XCTAssertEqual(diff.priorityChanges.removed, [.lateralDelts])
        XCTAssertFalse(diff.priorityChanges.reordered)

        current.developmentPriorities = [
            .init(muscle: .lats, reason: "b"),
            .init(muscle: .lateralDelts, reason: "a")
        ]
        previous.developmentPriorities = [
            .init(muscle: .lateralDelts, reason: "a"),
            .init(muscle: .lats, reason: "b")
        ]
        let reorder = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
        XCTAssertTrue(reorder.priorityChanges.reordered)
        XCTAssertTrue(reorder.priorityChanges.added.isEmpty)
        XCTAssertTrue(reorder.priorityChanges.removed.isEmpty)
    }

    func testDirectionAddRemoveSkipsUnknownCatalogIds() {
        var previous = FixtureBuilders.makePhysiqueAssessment()
        var current = FixtureBuilders.makePhysiqueAssessment()
        previous.physiqueDirections = [
            PhysiqueArchetypeMatch(
                archetypeId: "lean_fighter",
                rank: 1,
                similarityDimension: "silhouette",
                confidence: .medium
            )
        ]
        current.physiqueDirections = [
            PhysiqueArchetypeMatch(
                archetypeId: "v_taper_focus",
                rank: 1,
                similarityDimension: "taper",
                confidence: .medium
            ),
            PhysiqueArchetypeMatch(
                archetypeId: "not_in_catalog_xyz",
                rank: 2,
                similarityDimension: "x",
                confidence: .low
            )
        ]
        let diff = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
        XCTAssertEqual(Set(diff.directionChanges.added), ["v_taper_focus", "not_in_catalog_xyz"])
        XCTAssertEqual(diff.directionChanges.removed, ["lean_fighter"])
        let joined = diff.summaryLines.joined(separator: " ")
        XCTAssertTrue(joined.contains("V-taper focus") || joined.lowercased().contains("v-taper"))
        XCTAssertFalse(joined.contains("not_in_catalog_xyz"))
    }

    func testVisionTrendsWhenBothRatiosPresent() {
        let previous = FixtureBuilders.makePhysiqueAssessment()
        let current = FixtureBuilders.makePhysiqueAssessment()
        let diff = PhysiqueAssessmentDiffEngine.diff(
            previous: previous,
            current: current,
            previousFrontRatio: 1.30,
            currentFrontRatio: 1.40
        )
        XCTAssertFalse(diff.visionTrends.isEmpty)
        XCTAssertTrue(diff.visionTrends[0].localizedCaseInsensitiveContains("wider"))
    }

    func testVisionTrendsOmittedWhenRatioMissing() {
        let previous = FixtureBuilders.makePhysiqueAssessment()
        let current = FixtureBuilders.makePhysiqueAssessment()
        let diff = PhysiqueAssessmentDiffEngine.diff(
            previous: previous,
            current: current,
            previousFrontRatio: 1.30,
            currentFrontRatio: nil
        )
        XCTAssertTrue(diff.visionTrends.isEmpty)
    }

    func testStableSummaryWhenNothingChanged() {
        let previous = FixtureBuilders.makePhysiqueAssessment(id: UUID())
        let current = FixtureBuilders.makePhysiqueAssessment(id: UUID())
        let diff = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
        XCTAssertFalse(diff.hasMeaningfulChange)
        XCTAssertEqual(diff.summaryLines, ["No meaningful change since last assessment."])
    }
}
