import XCTest
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
