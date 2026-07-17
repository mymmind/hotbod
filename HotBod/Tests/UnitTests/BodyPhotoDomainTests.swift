import XCTest
import UIKit
@testable import HotBod

final class BodyPhotoVisionMetricsTests: XCTestCase {
    func testComparisonSummaryStable() {
        let summary = BodyPhotoVisionMetrics.comparisonSummary(
            currentRatio: 1.35,
            previousRatio: 1.34,
            hasPrevious: true
        )
        XCTAssertTrue(summary.contains("stable"))
    }

    func testComparisonSummaryBaseline() {
        let summary = BodyPhotoVisionMetrics.comparisonSummary(
            currentRatio: nil,
            previousRatio: nil,
            hasPrevious: false
        )
        XCTAssertEqual(summary, "Baseline photo captured.")
    }

    func testSleepScoreMapping() {
        XCTAssertEqual(HealthKitReadinessServiceImpl.sleepScore(hours: 4), 0.35)
        XCTAssertEqual(HealthKitReadinessServiceImpl.sleepScore(hours: 8), 0.95)
    }

    func testRecoveryHintShortSleep() {
        let hint = HealthKitReadinessServiceImpl.recoveryHint(restingHeartRate: 58, sleepHours: 5)
        XCTAssertTrue(hint?.contains("Sleep") == true)
    }
}

final class BodyProgressPhotoTimelineTests: XCTestCase {
    func testLatestMatchingPoseUsesMostRecentDate() {
        let older = makePhoto(pose: .frontRelaxed, date: Date(timeIntervalSince1970: 100))
        let newer = makePhoto(pose: .frontRelaxed, date: Date(timeIntervalSince1970: 200))
        let side = makePhoto(pose: .sideRelaxed, date: Date(timeIntervalSince1970: 300))

        let latest = BodyProgressPhoto.latest(matching: .frontRelaxed, in: [older, newer, side])
        XCTAssertEqual(latest?.id, newer.id)
    }

    func testLatestPairRequiresMatchingPose() {
        let frontOld = makePhoto(pose: .frontRelaxed, date: Date(timeIntervalSince1970: 100))
        let frontNew = makePhoto(pose: .frontRelaxed, date: Date(timeIntervalSince1970: 200))
        let side = makePhoto(pose: .sideRelaxed, date: Date(timeIntervalSince1970: 300))

        XCTAssertNil(BodyProgressPhoto.latestPair(matching: .frontRelaxed, in: [frontOld, side]))
        let pair = BodyProgressPhoto.latestPair(matching: .frontRelaxed, in: [frontOld, frontNew, side])
        XCTAssertEqual(pair?.latest.id, frontNew.id)
        XCTAssertEqual(pair?.previous.id, frontOld.id)
    }

    func testAverageLightingScore() {
        var first = makePhoto(pose: .frontRelaxed, date: Date())
        first.analysis = BodyPhotoAnalysis(
            poseConfidence: 0.8,
            lightingScore: 0.6,
            framingScore: 0.8,
            shoulderWidthEstimate: nil,
            waistWidthEstimate: nil,
            hipWidthEstimate: nil,
            shoulderWaistRatio: nil,
            postureNotes: [],
            comparisonSummary: nil,
            limitations: []
        )
        var second = makePhoto(pose: .sideRelaxed, date: Date())
        second.analysis = BodyPhotoAnalysis(
            poseConfidence: 0.8,
            lightingScore: 0.8,
            framingScore: 0.8,
            shoulderWidthEstimate: nil,
            waistWidthEstimate: nil,
            hipWidthEstimate: nil,
            shoulderWaistRatio: nil,
            postureNotes: [],
            comparisonSummary: nil,
            limitations: []
        )

        XCTAssertEqual(BodyProgressPhoto.averageLightingScore(in: [first, second]), 0.7)
    }

    func testImageProcessorNormalizesOrientation() {
        let size = CGSize(width: 40, height: 20)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let base = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        guard let cgImage = base.cgImage else {
            XCTFail("Expected cgImage")
            return
        }
        let oriented = UIImage(cgImage: cgImage, scale: 1, orientation: .left)
        let normalized = BodyPhotoImageProcessor.normalizedImage(oriented)
        XCTAssertEqual(normalized.imageOrientation, .up)
        XCTAssertGreaterThan(normalized.size.width, 0)
        XCTAssertGreaterThan(normalized.size.height, 0)
    }

    func testFileExistsHelper() {
        XCTAssertFalse(BodyPhotoImageProcessor.fileExists(at: "/tmp/definitely-missing-\(UUID().uuidString).jpg"))
    }

    func testPathResolverPrefersRelativeFilenameUnderPhotosDirectory() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let filename = "\(UUID().uuidString).jpg"
            let url = BodyPhotoPathResolver.photosDirectory.appendingPathComponent(filename)
            try FileManager.default.createDirectory(
                at: BodyPhotoPathResolver.photosDirectory,
                withIntermediateDirectories: true
            )
            try Data("x".utf8).write(to: url)

            let resolvedRelative = BodyPhotoPathResolver.resolve(filename)
            XCTAssertEqual(resolvedRelative.lastPathComponent, filename)
            XCTAssertTrue(FileManager.default.fileExists(atPath: resolvedRelative.path))

            let resolvedAbsolute = BodyPhotoPathResolver.resolve(url.path)
            XCTAssertEqual(resolvedAbsolute.path, url.path)

            let photo = BodyProgressPhoto(
                id: UUID(),
                userId: UUID(),
                date: Date(),
                poseType: .frontRelaxed,
                localImagePath: url.path
            )
            let migrated = BodyPhotoPathResolver.migratedPhoto(from: photo)
            XCTAssertEqual(migrated?.localImagePath, filename)
        }
    }

    private func makePhoto(pose: BodyPhotoPoseType, date: Date) -> BodyProgressPhoto {
        BodyProgressPhoto(
            id: UUID(),
            userId: UUID(),
            date: date,
            poseType: pose,
            localImagePath: "/tmp/\(UUID().uuidString).jpg"
        )
    }
}
