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

    func testWithoutSideRanksTrapsNotRearDelts() async throws {
        let service = OfflinePhysiqueAssessmentService()
        let result = try await service.assess(FixtureBuilders.makePhysiqueAssessmentRequest(includeSide: false))

        let rankedMuscles = result.developmentPriorities.map(\.muscle)
        XCTAssertTrue(rankedMuscles.contains(.traps))
        XCTAssertFalse(rankedMuscles.contains(.rearDelts))

        let rearDeltsEntry = result.muscleEntries.first { $0.muscle == .rearDelts }
        XCTAssertNotNil(rearDeltsEntry)
        XCTAssertEqual(rearDeltsEntry?.confidence, .uncertain)
        XCTAssertNil(rearDeltsEntry?.priorityRank)
    }

    func testWithSideRanksRearDelts() async throws {
        let service = OfflinePhysiqueAssessmentService()
        let result = try await service.assess(FixtureBuilders.makePhysiqueAssessmentRequest(includeSide: true))

        let rankedMuscles = result.developmentPriorities.map(\.muscle)
        XCTAssertTrue(rankedMuscles.contains(.rearDelts))
        XCTAssertFalse(rankedMuscles.contains(.traps))

        let rearDeltsEntry = result.muscleEntries.first { $0.muscle == .rearDelts }
        XCTAssertNotNil(rearDeltsEntry)
        XCTAssertNotNil(rearDeltsEntry?.priorityRank)
        XCTAssertNotEqual(rearDeltsEntry?.confidence, .uncertain)
    }

    func testPoorSidePhotoStillRaisesConfidenceOverNoSide() async throws {
        let service = OfflinePhysiqueAssessmentService()
        let without = try await service.assess(FixtureBuilders.makePhysiqueAssessmentRequest(includeSide: false))
        let withPoorSide = try await service.assess(
            FixtureBuilders.makePhysiqueAssessmentRequest(includeSide: true, poorSideMetrics: true)
        )
        XCTAssertGreaterThan(withPoorSide.photoQuality.overallConfidence, without.photoQuality.overallConfidence)
    }
}

final class PhysiqueAssessmentSanitizerTests: XCTestCase {
    func testRemotePayloadMapperDropsUnknownMusclesAndUncertainPriorities() {
        let payloadPriorities = ["lateralDelts", "not_a_muscle", "rearDelts"]
        let confidences = ["high", "high", "uncertain"]
        let muscles = PhysiqueAssessmentSanitizer.priorities(
            rawIds: payloadPriorities,
            confidences: confidences
        )
        XCTAssertEqual(muscles, [.lateralDelts])
    }

    func testSanitizeDevelopmentPrioritiesRemovesUncertainMuscles() {
        let payload = RemotePhysiqueAssessmentPayload(
            photoQuality: RemotePhysiquePhotoQualityPayload(
                anglesAvailable: ["front", "back"],
                lightingQuality: "Even",
                overallConfidence: 0.7
            ),
            physique: RemotePhysiqueBuildSummaryPayload(
                overallArchetype: "Balanced build",
                frameSize: "Medium",
                shoulderToWaist: "Moderate contrast",
                waist: "Defined",
                torso: "Balanced",
                muscularity: "Moderate",
                leanness: "Moderate"
            ),
            muscleEntries: [
                RemotePhysiqueMuscleEntryPayload(
                    muscle: "lateralDelts",
                    current: "Moderate",
                    priorityRank: 1,
                    notes: "Front visible",
                    confidence: "high"
                ),
                RemotePhysiqueMuscleEntryPayload(
                    muscle: "rearDelts",
                    current: "Unknown",
                    priorityRank: nil,
                    notes: "Side missing",
                    confidence: "uncertain"
                )
            ],
            developmentPriorities: [
                RemotePhysiqueDevelopmentPriorityPayload(
                    muscle: "lateralDelts",
                    reason: "Shoulder width."
                ),
                RemotePhysiqueDevelopmentPriorityPayload(
                    muscle: "rearDelts",
                    reason: "Should not appear."
                )
            ],
            trainingBias: RemotePhysiqueTrainingBiasPayload(
                preferredMuscleGroups: ["shoulders", "back"],
                rationale: "Server bias"
            ),
            limitations: ["Visual estimate only."],
            confidenceBands: RemotePhysiqueConfidenceBandsPayload(
                high: [],
                medium: [],
                low: ["Rear delts"]
            ),
            whyTodaySummary: "Bias shoulders."
        )

        let request = FixtureBuilders.makePhysiqueAssessmentRequest(includeSide: false)
        let assessment = PhysiqueAssessmentSanitizer.map(payload, request: request)

        XCTAssertEqual(assessment.source, .cloud)
        XCTAssertEqual(assessment.developmentPriorities.map(\.muscle), [.lateralDelts])
        XCTAssertEqual(assessment.trainingBias.preferredMuscleGroups, [.shoulders])
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
