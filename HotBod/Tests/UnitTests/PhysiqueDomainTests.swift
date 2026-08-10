import XCTest
@testable import HotBod

final class PhysiqueFocusMuscleMappingTests: XCTestCase {
    func testLateralDeltsMapToShoulders() {
        XCTAssertEqual(PhysiqueFocusMuscle.lateralDelts.muscleGroups, [.shoulders])
    }

    func testLatsMapToBack() {
        XCTAssertEqual(PhysiqueFocusMuscle.lats.muscleGroups, [.back])
    }

    func testUpperChestMapsToChest() {
        XCTAssertEqual(PhysiqueFocusMuscle.upperChest.muscleGroups, [.chest])
    }

    func testPhysiqueAssessmentRoundTripsCodable() throws {
        let assessment = FixtureBuilders.makePhysiqueAssessment()
        let data = try JSONEncoder().encode(assessment)
        let decoded = try JSONDecoder().decode(PhysiqueAssessment.self, from: data)
        XCTAssertEqual(decoded.id, assessment.id)
        XCTAssertEqual(decoded.trainingBias.preferredMuscleGroups, [.shoulders, .back, .chest])
        XCTAssertFalse(decoded.limitations.contains { $0.localizedCaseInsensitiveContains("body fat %") })
    }
}
