import XCTest
@testable import HotBod

final class HealthKitWorkoutBuilderTests: XCTestCase {
    func testIntervalUsesStartedAndCompletedAt() {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = start.addingTimeInterval(2_700)
        var session = FixtureBuilders.makeWorkoutSession(status: .completed)
        session.startedAt = start
        session.completedAt = end

        let interval = HealthKitWorkoutBuilder.interval(for: session)
        XCTAssertNotNil(interval)
        XCTAssertEqual(interval?.start, start)
        XCTAssertEqual(interval?.end, end)
        XCTAssertEqual(interval?.duration ?? 0, 2_700, accuracy: 0.1)
    }

    func testEnergyBurnedUsesSessionDurationAndBodyWeight() {
        var session = FixtureBuilders.makeWorkoutSession(status: .completed)
        session.startedAt = Date()
        session.completedAt = session.startedAt?.addingTimeInterval(3_600)

        let kcal = HealthKitWorkoutBuilder.energyBurnedKcal(session: session, bodyWeightKg: 80)
        XCTAssertEqual(kcal ?? 0, 400, accuracy: 1)
    }
}

final class StravaIntegrationServiceTests: XCTestCase {
    func testNoOpServiceIsNotConfigured() async {
        let service = NoOpStravaIntegrationService()
        XCTAssertFalse(service.isConfigured)
        XCTAssertFalse(service.isConnected)
        do {
            try await service.connect()
            XCTFail("Expected notConfigured")
        } catch let error as StravaIntegrationError {
            XCTAssertEqual(error, .notConfigured)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}

final class P3LocalizationTests: XCTestCase {
    func testIntegrationStringsAreNonEmpty() {
        XCTAssertFalse(L10n.Settings.integrationsTitle.isEmpty)
        XCTAssertFalse(L10n.Settings.healthExportTitle.isEmpty)
        XCTAssertFalse(L10n.Workout.completeTitle.isEmpty)
    }
}
