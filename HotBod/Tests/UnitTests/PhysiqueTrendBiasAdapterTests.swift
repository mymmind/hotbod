import XCTest
@testable import HotBod

final class PhysiqueTrendBiasAdapterTests: XCTestCase {
    func testAppearedPriorityBoostsBiasAndSetsAdaptation() {
        var previous = FixtureBuilders.makePhysiqueAssessment()
        previous.developmentPriorities = [
            .init(muscle: .lats, reason: "a"),
            .init(muscle: .upperChest, reason: "b")
        ]
        var current = FixtureBuilders.makePhysiqueAssessment()
        current.developmentPriorities = [
            .init(muscle: .lateralDelts, reason: "c"),
            .init(muscle: .lats, reason: "a")
        ]
        let diff = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
        let result = PhysiqueTrendBiasAdapter.adapt(current: current, previous: previous, diff: diff)
        XCTAssertTrue(result.didAdapt)
        XCTAssertEqual(result.assessment.developmentPriorities.map(\.muscle), current.developmentPriorities.map(\.muscle))
        XCTAssertEqual(result.assessment.trainingBias.preferredMuscleGroups.first, .shoulders)
        XCTAssertTrue(result.reasons.contains { $0.contains("Lateral Delts") && $0.contains("appeared") })
        XCTAssertEqual(result.assessment.trendAdaptation?.previousAssessmentId, previous.id)
    }

    func testMovedUpBoostsBias() {
        var previous = FixtureBuilders.makePhysiqueAssessment()
        previous.developmentPriorities = [
            .init(muscle: .lateralDelts, reason: "a"),
            .init(muscle: .lats, reason: "b")
        ]
        var current = FixtureBuilders.makePhysiqueAssessment()
        current.developmentPriorities = [
            .init(muscle: .lats, reason: "b"),
            .init(muscle: .lateralDelts, reason: "a")
        ]
        let diff = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
        let result = PhysiqueTrendBiasAdapter.adapt(current: current, previous: previous, diff: diff)
        XCTAssertTrue(result.didAdapt)
        XCTAssertTrue(result.reasons.contains { $0.contains("Lats") && $0.contains("moved up") })
        XCTAssertEqual(result.assessment.trainingBias.preferredMuscleGroups.first, .back)
    }

    func testVisionWiderBoostsShouldersWhenPriorityMaps() {
        var previous = FixtureBuilders.makePhysiqueAssessment()
        var current = FixtureBuilders.makePhysiqueAssessment()
        current.developmentPriorities = [
            .init(muscle: .lateralDelts, reason: "caps"),
            .init(muscle: .lats, reason: "width")
        ]
        let diff = PhysiqueAssessmentDiff(
            previousId: previous.id,
            currentId: current.id,
            previousDate: previous.createdAt,
            currentDate: current.createdAt,
            buildChanges: [],
            priorityChanges: PhysiquePriorityChanges(added: [], removed: [], reordered: false),
            directionChanges: PhysiqueDirectionChanges(added: [], removed: []),
            visionTrends: ["Visual trend: shoulder-to-waist ratio slightly wider (3.0%)."],
            summaryLines: ["No meaningful change since last assessment."],
            hasMeaningfulChange: false
        )
        let result = PhysiqueTrendBiasAdapter.adapt(current: current, previous: previous, diff: diff)
        XCTAssertTrue(result.didAdapt)
        XCTAssertEqual(result.assessment.trainingBias.preferredMuscleGroups.first, .shoulders)
        XCTAssertTrue(result.reasons.contains { $0.contains("wider") })
    }

    func testVisionWiderWithoutShoulderPriorityDoesNotBoostFromVision() {
        var previous = FixtureBuilders.makePhysiqueAssessment()
        var current = FixtureBuilders.makePhysiqueAssessment()
        current.developmentPriorities = [
            .init(muscle: .quads, reason: "legs"),
            .init(muscle: .glutes, reason: "hips")
        ]
        previous.developmentPriorities = current.developmentPriorities
        let diff = PhysiqueAssessmentDiff(
            previousId: previous.id,
            currentId: current.id,
            previousDate: previous.createdAt,
            currentDate: current.createdAt,
            buildChanges: [],
            priorityChanges: PhysiquePriorityChanges(added: [], removed: [], reordered: false),
            directionChanges: PhysiqueDirectionChanges(added: [], removed: []),
            visionTrends: ["Visual trend: shoulder-to-waist ratio slightly wider (3.0%)."],
            summaryLines: ["No meaningful change since last assessment."],
            hasMeaningfulChange: false
        )
        let result = PhysiqueTrendBiasAdapter.adapt(current: current, previous: previous, diff: diff)
        XCTAssertFalse(result.didAdapt)
        XCTAssertNil(result.assessment.trendAdaptation)
    }

    func testNoSignalsDoesNotAdapt() {
        let sharedPriorities = [
            PhysiqueDevelopmentPriority(muscle: .lateralDelts, reason: "a"),
            PhysiqueDevelopmentPriority(muscle: .lats, reason: "b")
        ]
        let previous = FixtureBuilders.makePhysiqueAssessment(developmentPriorities: sharedPriorities)
        let current = FixtureBuilders.makePhysiqueAssessment(developmentPriorities: sharedPriorities)
        let diff = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
        let result = PhysiqueTrendBiasAdapter.adapt(current: current, previous: previous, diff: diff)
        XCTAssertFalse(result.didAdapt)
        XCTAssertNil(result.assessment.trendAdaptation)
        XCTAssertEqual(result.assessment.trainingBias, current.trainingBias)
    }

    func testReasonsCapAtThree() {
        var previous = FixtureBuilders.makePhysiqueAssessment()
        previous.developmentPriorities = [
            .init(muscle: .calves, reason: "z")
        ]
        var current = FixtureBuilders.makePhysiqueAssessment()
        current.developmentPriorities = [
            .init(muscle: .lateralDelts, reason: "a"),
            .init(muscle: .lats, reason: "b"),
            .init(muscle: .upperChest, reason: "c"),
            .init(muscle: .abs, reason: "d")
        ]
        let diff = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
        let result = PhysiqueTrendBiasAdapter.adapt(current: current, previous: previous, diff: diff)
        XCTAssertTrue(result.didAdapt)
        XCTAssertEqual(result.reasons.count, 3)
        XCTAssertEqual(result.assessment.trendAdaptation?.reasons.count, 3)
    }
}
