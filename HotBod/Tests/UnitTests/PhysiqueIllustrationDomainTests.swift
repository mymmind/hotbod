import UIKit
import XCTest
@testable import HotBod

final class PhysiqueIllustrationDomainTests: XCTestCase {
    func testHintsBuilderUsesGenericLabelsOnlyAndCapsPriorities() {
        var assessment = FixtureBuilders.makePhysiqueAssessment()
        assessment.developmentPriorities = [
            .init(muscle: .lateralDelts, reason: "a"),
            .init(muscle: .lats, reason: "b"),
            .init(muscle: .upperChest, reason: "c"),
            .init(muscle: .abs, reason: "d")
        ]
        assessment.physiqueDirections = [
            PhysiqueArchetypeMatch(
                archetypeId: "classic_athletic",
                rank: 1,
                similarityDimension: "taper",
                confidence: .high
            )
        ]
        let hints = PhysiqueIllustrationHintsBuilder.make(from: assessment)
        XCTAssertEqual(hints.priorityMuscles.count, 3)
        XCTAssertEqual(hints.priorityMuscles, [.lateralDelts, .lats, .upperChest])
        XCTAssertEqual(hints.directionGenericLabels, ["Classic athletic"])
        XCTAssertFalse(hints.directionGenericLabels.joined().localizedCaseInsensitiveContains("Brad"))
        XCTAssertFalse(hints.directionGenericLabels.joined().localizedCaseInsensitiveContains("Pitt"))
    }

    func testImageCodecRespectsMaxEdge() {
        let size = CGSize(width: 2000, height: 1500)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.gray.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        let data = PhysiqueIllustrationImageCodec.jpegDataForUpload(from: image)
        XCTAssertNotNil(data)
        let out = UIImage(data: data!)!
        XCTAssertLessThanOrEqual(max(out.size.width, out.size.height), 1024 + 1)
    }

    func testStoreSaveFetchReplaceAndClearAll() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let store = LocalPhysiqueIllustrationStore(
                directoryName: "physique_illustrations_test_\(UUID().uuidString)"
            )
            let id = UUID()
            let photoId = UUID()
            let jpeg = PhysiqueIllustrationImageCodec.jpegDataForUpload(
                from: UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in }
            )!
            _ = try await store.save(assessmentId: id, sourcePhotoId: photoId, imageData: jpeg)
            let loaded = try await store.fetch(assessmentId: id)
            XCTAssertEqual(loaded?.0.assessmentId, id)
            XCTAssertEqual(loaded?.0.sourcePhotoId, photoId)
            XCTAssertFalse(loaded!.1.isEmpty)

            let jpeg2 = jpeg
            _ = try await store.save(assessmentId: id, sourcePhotoId: UUID(), imageData: jpeg2)
            let replaced = try await store.fetch(assessmentId: id)
            XCTAssertNotEqual(replaced?.0.sourcePhotoId, photoId)

            try await store.clearAll()
            let cleared = try await store.fetch(assessmentId: id)
            XCTAssertNil(cleared)
        }
    }
}
