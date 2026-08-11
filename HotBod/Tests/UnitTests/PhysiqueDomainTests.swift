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

    func testPhysiqueAssessmentDecodesMissingBackPhotoIdAsNil() throws {
        var assessment = FixtureBuilders.makePhysiqueAssessment(backPhotoId: nil)
        let data = try JSONEncoder().encode(assessment)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return XCTFail("Expected encoded assessment to be a JSON object")
        }
        object.removeValue(forKey: "backPhotoId")
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(PhysiqueAssessment.self, from: stripped)
        XCTAssertNil(decoded.backPhotoId)
    }
}

final class PhysiquePhotoGateTests: XCTestCase {
    func testFrontOnlyIsReady() {
        let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed)
        guard case .ready(let selection) = PhysiquePhotoGate.evaluate(photos: [front]) else {
            return XCTFail("expected ready")
        }
        XCTAssertEqual(selection.front.id, front.id)
        XCTAssertNil(selection.back)
        XCTAssertNil(selection.side)
    }

    func testMissingFrontOnly() {
        let back = FixtureBuilders.makeBodyPhoto(pose: .backRelaxed)
        let result = PhysiquePhotoGate.evaluate(photos: [back])
        guard case .missingAngles(let missing) = result else {
            return XCTFail("expected missingAngles")
        }
        XCTAssertEqual(missing, [.front])
    }

    func testBackQualityFailureOmitsBackButStaysReady() {
        let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed)
        var back = FixtureBuilders.makeBodyPhoto(pose: .backRelaxed)
        back.analysis?.poseConfidence = 0.1
        guard case .ready(let selection) = PhysiquePhotoGate.evaluate(photos: [front, back]) else {
            return XCTFail("expected ready")
        }
        XCTAssertNil(selection.back)
    }

    func testStaleIgnoresBackWhenAssessmentHasNoBackPhotoId() {
        var assessment = FixtureBuilders.makePhysiqueAssessment(backPhotoId: nil)
        assessment.createdAt = Date().addingTimeInterval(-1000)
        let front = FixtureBuilders.makeBodyPhoto(
            pose: .frontRelaxed,
            date: assessment.createdAt.addingTimeInterval(-10)
        )
        let back = FixtureBuilders.makeBodyPhoto(pose: .backRelaxed, date: Date())
        XCTAssertFalse(PhysiquePhotoGate.isStale(active: assessment, photos: [front, back]))
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

    func testSideQualityFailureDoesNotBlockAssessment() {
        let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed)
        let back = FixtureBuilders.makeBodyPhoto(pose: .backRelaxed)
        var side = FixtureBuilders.makeBodyPhoto(pose: .sideRelaxed)
        side.analysis?.poseConfidence = 0.1

        guard case .ready(let selection) = PhysiquePhotoGate.evaluate(
            photos: [front, back, side]
        ) else {
            return XCTFail("expected ready")
        }

        XCTAssertEqual(selection.front.id, front.id)
        XCTAssertEqual(selection.back?.id, back.id)
        XCTAssertNil(selection.side)
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
        XCTAssertFalse(result.physiqueDirections.isEmpty)
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

    func testFrontOnlyOfflineAssessSucceedsWithNilBackPhotoId() async throws {
        let service = OfflinePhysiqueAssessmentService()
        let request = FixtureBuilders.makePhysiqueAssessmentRequest(includeBack: false, includeSide: false)
        let result = try await service.assess(request)
        let withBack = try await service.assess(FixtureBuilders.makePhysiqueAssessmentRequest(includeBack: true))
        XCTAssertNil(result.backPhotoId)
        XCTAssertEqual(result.photoQuality.anglesAvailable, ["front"])
        XCTAssertTrue(result.limitations.contains { $0.localizedCaseInsensitiveContains("back") })
        XCTAssertLessThan(result.photoQuality.overallConfidence, withBack.photoQuality.overallConfidence)
    }
}

final class HybridPhysiqueAssessmentServiceTests: XCTestCase {
    func testRegateFailsWhenFrontQualityBadAfterAnalysis() async {
        let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed, analysis: nil)
        let back = FixtureBuilders.makeBodyPhoto(pose: .backRelaxed, analysis: nil)
        let service = HybridPhysiqueAssessmentService(
            remote: UnavailablePhysiqueAssessmentService(),
            offline: OfflinePhysiqueAssessmentService(),
            analyzer: ConfigurableBodyPhotoAnalyzer(frontPoseConfidence: 0.1)
        )

        do {
            _ = try await service.assess(photos: [front, back], profile: UserProfile.empty())
            XCTFail("expected quality failure")
        } catch let error as PhysiqueAssessmentError {
            guard case .qualityFailed(let failures) = error else {
                return XCTFail("expected qualityFailed")
            }
            XCTAssertEqual(failures.first?.0, .front)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testRegateDropsSideWhenSideQualityBadAfterAnalysis() async throws {
        let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed, analysis: nil)
        let back = FixtureBuilders.makeBodyPhoto(pose: .backRelaxed, analysis: nil)
        let side = FixtureBuilders.makeBodyPhoto(pose: .sideRelaxed, analysis: nil)
        let service = HybridPhysiqueAssessmentService(
            remote: UnavailablePhysiqueAssessmentService(),
            offline: OfflinePhysiqueAssessmentService(),
            analyzer: ConfigurableBodyPhotoAnalyzer(sidePoseConfidence: 0.1)
        )

        let result = try await service.assess(
            photos: [front, back, side],
            profile: UserProfile.empty()
        )

        XCTAssertNil(result.sidePhotoId)
        XCTAssertEqual(result.source, .onDevice)
    }

    func testPersistsFreshAnalysisToBodyProgressRepository() async throws {
        let repos = TestRepositories.empty()
        var front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed, analysis: nil)
        var back = FixtureBuilders.makeBodyPhoto(pose: .backRelaxed, analysis: nil)
        try await repos.bodyProgress.savePhoto(front)
        try await repos.bodyProgress.savePhoto(back)

        let service = HybridPhysiqueAssessmentService(
            remote: UnavailablePhysiqueAssessmentService(),
            offline: OfflinePhysiqueAssessmentService(),
            analyzer: MockBodyPhotoAnalyzer(),
            bodyProgress: repos.bodyProgress
        )

        _ = try await service.assess(photos: [front, back], profile: UserProfile.empty())

        let saved = try await repos.bodyProgress.fetchPhotos()
        let savedFront = saved.first { $0.id == front.id }
        let savedBack = saved.first { $0.id == back.id }
        XCTAssertNotNil(savedFront?.analysis)
        XCTAssertNotNil(savedBack?.analysis)
    }
}

private struct ConfigurableBodyPhotoAnalyzer: BodyPhotoAnalyzer, Sendable {
    var frontPoseConfidence: Double = 0.82
    var backPoseConfidence: Double = 0.82
    var sidePoseConfidence: Double = 0.82

    func analyze(photo: BodyProgressPhoto, previous: BodyProgressPhoto?) async throws -> BodyPhotoAnalysis {
        let poseConfidence: Double
        switch photo.poseType {
        case .frontRelaxed, .frontFlexed:
            poseConfidence = frontPoseConfidence
        case .backRelaxed, .backFlexed:
            poseConfidence = backPoseConfidence
        case .sideRelaxed, .sideFlexed:
            poseConfidence = sidePoseConfidence
        }

        return BodyPhotoAnalysis(
            poseConfidence: poseConfidence,
            lightingScore: 0.75,
            framingScore: 0.88,
            shoulderWidthEstimate: 0.42,
            waistWidthEstimate: 0.31,
            hipWidthEstimate: 0.35,
            shoulderWaistRatio: 1.35,
            postureNotes: [],
            comparisonSummary: nil,
            limitations: []
        )
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
            whyTodaySummary: "Bias shoulders.",
            physiqueDirections: []
        )

        let request = FixtureBuilders.makePhysiqueAssessmentRequest(includeSide: false)
        let assessment = PhysiqueAssessmentSanitizer.map(payload, request: request)

        XCTAssertEqual(assessment.source, .cloud)
        XCTAssertEqual(assessment.developmentPriorities.map(\.muscle), [.lateralDelts])
        XCTAssertEqual(assessment.trainingBias.preferredMuscleGroups, [.shoulders])
    }

    func testSanitizeDevelopmentPrioritiesDropsOrphanPrioritiesWithoutMuscleEntry() {
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
                )
            ],
            developmentPriorities: [
                RemotePhysiqueDevelopmentPriorityPayload(
                    muscle: "lateralDelts",
                    reason: "Shoulder width."
                ),
                RemotePhysiqueDevelopmentPriorityPayload(
                    muscle: "rearDelts",
                    reason: "No matching muscle entry."
                )
            ],
            trainingBias: RemotePhysiqueTrainingBiasPayload(
                preferredMuscleGroups: ["shoulders"],
                rationale: "Server bias"
            ),
            limitations: ["Visual estimate only."],
            confidenceBands: RemotePhysiqueConfidenceBandsPayload(
                high: [],
                medium: [],
                low: []
            ),
            whyTodaySummary: "Bias shoulders.",
            physiqueDirections: []
        )

        let request = FixtureBuilders.makePhysiqueAssessmentRequest(includeSide: false)
        let assessment = PhysiqueAssessmentSanitizer.map(payload, request: request)

        XCTAssertEqual(assessment.developmentPriorities.map(\.muscle), [.lateralDelts])
    }

    func testScrubFreeTextRemovesDisallowedCloudPhrasing() {
        let payload = RemotePhysiqueAssessmentPayload(
            photoQuality: RemotePhysiquePhotoQualityPayload(
                anglesAvailable: ["front", "back"],
                lightingQuality: "Even",
                overallConfidence: 0.7
            ),
            physique: RemotePhysiqueBuildSummaryPayload(
                overallArchetype: "You are genetically an ectomorph at 18% body fat %",
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
                    current: "Estimated body fat percent from photo",
                    priorityRank: 1,
                    notes: "Diagnosed with low muscle tone",
                    confidence: "high"
                )
            ],
            developmentPriorities: [
                RemotePhysiqueDevelopmentPriorityPayload(
                    muscle: "lateralDelts",
                    reason: "Genetically limited delts need work."
                )
            ],
            trainingBias: RemotePhysiqueTrainingBiasPayload(
                preferredMuscleGroups: ["shoulders"],
                rationale: "Body fat percent estimate suggests bias shoulders."
            ),
            limitations: ["Medical diagnosis: not applicable.", "Visual estimate only."],
            confidenceBands: RemotePhysiqueConfidenceBandsPayload(
                high: [],
                medium: [],
                low: []
            ),
            whyTodaySummary: "Bias shoulders despite body fat % estimate.",
            physiqueDirections: []
        )

        let request = FixtureBuilders.makePhysiqueAssessmentRequest(includeSide: false)
        let assessment = PhysiqueAssessmentSanitizer.map(payload, request: request)
        let joined = (
            [assessment.physique.overallArchetype, assessment.whyTodaySummary, assessment.trainingBias.rationale]
                + assessment.limitations
                + assessment.muscleEntries.flatMap { [$0.current, $0.notes] }
                + assessment.developmentPriorities.map(\.reason)
        ).joined(separator: " ")

        XCTAssertFalse(joined.localizedCaseInsensitiveContains("body fat %"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("body fat percent"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("genetically"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("diagnosed with"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("medical diagnosis"))
    }

    func testSanitizerMapAttachesCatalogBackedDirections() {
        let payload = RemotePhysiqueAssessmentPayload(
            photoQuality: RemotePhysiquePhotoQualityPayload(
                anglesAvailable: ["front", "back"],
                lightingQuality: "Even",
                overallConfidence: 0.75
            ),
            physique: RemotePhysiqueBuildSummaryPayload(
                overallArchetype: "Athletic build with moderate shoulder-to-waist contrast",
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
                )
            ],
            developmentPriorities: [
                RemotePhysiqueDevelopmentPriorityPayload(
                    muscle: "lateralDelts",
                    reason: "Shoulder width."
                )
            ],
            trainingBias: RemotePhysiqueTrainingBiasPayload(
                preferredMuscleGroups: ["shoulders"],
                rationale: "Server bias"
            ),
            limitations: ["Visual estimate only."],
            confidenceBands: RemotePhysiqueConfidenceBandsPayload(
                high: [],
                medium: [],
                low: []
            ),
            whyTodaySummary: "Bias shoulders.",
            physiqueDirections: [
                RemotePhysiqueArchetypeMatchPayload(
                    archetypeId: "not_real",
                    rank: 1,
                    similarityDimension: "Unknown silhouette",
                    confidence: "high"
                ),
                RemotePhysiqueArchetypeMatchPayload(
                    archetypeId: "classic_athletic",
                    rank: 2,
                    similarityDimension: "Moderate V-taper proportions",
                    confidence: "high"
                ),
                RemotePhysiqueArchetypeMatchPayload(
                    archetypeId: "lean_fighter",
                    rank: 3,
                    similarityDimension: "Compact lean frame",
                    confidence: "medium"
                )
            ]
        )

        let request = FixtureBuilders.makePhysiqueAssessmentRequest(includeSide: false)
        let assessment = PhysiqueAssessmentSanitizer.map(payload, request: request)

        XCTAssertEqual(assessment.physiqueDirections.count, 2)
        XCTAssertFalse(assessment.physiqueDirections.contains { $0.archetypeId == "not_real" })
        XCTAssertEqual(assessment.physiqueDirections.map(\.archetypeId), ["classic_athletic", "lean_fighter"])
        XCTAssertEqual(assessment.physiqueDirections.map(\.rank), [1, 2])
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
