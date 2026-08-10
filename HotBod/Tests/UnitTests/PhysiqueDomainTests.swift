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

final class PhysiquePhotoGateTests: XCTestCase {
    func testRequiresFrontAndBack() {
        let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed)
        let result = PhysiquePhotoGate.evaluate(photos: [front])
        guard case .missingAngles(let missing) = result else {
            return XCTFail("expected missingAngles")
        }
        XCTAssertTrue(missing.contains(.back))
    }

    func testSideOptionalWhenFrontAndBackPresent() {
        let photos = [
            FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed),
            FixtureBuilders.makeBodyPhoto(pose: .backRelaxed)
        ]
        guard case .ready(let selection) = PhysiquePhotoGate.evaluate(photos: photos) else {
            return XCTFail("expected ready")
        }
        XCTAssertNil(selection.side)
    }

    func testQualityFailureOnLowPoseConfidence() {
        var front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed)
        front.analysis?.poseConfidence = 0.1
        let back = FixtureBuilders.makeBodyPhoto(pose: .backRelaxed)
        let result = PhysiquePhotoGate.evaluate(photos: [front, back])
        guard case .qualityFailed(let failures) = result else {
            return XCTFail("expected qualityFailed")
        }
        XCTAssertEqual(failures.first?.angle, .front)
    }
}

final class OfflinePhysiqueAssessmentTests: XCTestCase {
    func testProducesOnDeviceSourceAndBiasWithoutBodyFatPercent() async throws {
        let service = OfflinePhysiqueAssessmentService()
        let request = FixtureBuilders.makePhysiqueAssessmentRequest(includeSide: false)
        let result = try await service.assess(request)
        XCTAssertEqual(result.source, .onDevice)
        XCTAssertFalse(result.trainingBias.preferredMuscleGroups.isEmpty)
        XCTAssertFalse(result.whyTodaySummary.isEmpty)
        let joined = (result.limitations + [result.physique.overallArchetype, result.whyTodaySummary]).joined(separator: " ")
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("body fat %"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("genetically"))
    }

    func testSidePhotoRaisesConfidence() async throws {
        let service = OfflinePhysiqueAssessmentService()
        let without = try await service.assess(FixtureBuilders.makePhysiqueAssessmentRequest(includeSide: false))
        let with = try await service.assess(FixtureBuilders.makePhysiqueAssessmentRequest(includeSide: true))
        XCTAssertGreaterThan(with.photoQuality.overallConfidence, without.photoQuality.overallConfidence)
    }
}

final class PhysiqueTrainingBiasMergerTests: XCTestCase {
    func testAssessmentBiasPrecedesProfileAndDropsAvoided() {
        let merged = PhysiqueTrainingBiasMerger.mergePreferredMuscleGroups(
            profilePreferred: [.quads, .chest],
            assessmentBias: [.shoulders, .back, .chest],
            avoided: [.chest]
        )
        XCTAssertEqual(merged, [.shoulders, .back, .quads])
    }

    func testPrioritiesFlattenToMuscleGroups() {
        let groups = PhysiqueTrainingBiasMerger.preferredGroups(
            from: [.lateralDelts, .lats, .upperChest, .rearDelts]
        )
        XCTAssertEqual(groups, [.shoulders, .back, .chest])
    }
}
