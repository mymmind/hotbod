import XCTest
@testable import HotBod

// UI exemption: the RIR sheet and the two settings rows are user-facing.
// Their programming effects are covered by testRegression_skippedEffort and
// testRegression_untrustedHistoricEffort. No new UI test is added in this release.
// The Skip control keeps accessibility identifier workout.rir.skip.

final class WorkoutGeneratorP0Tests: XCTestCase {
    func testRegression_doubleProgression() {
        let stored = SessionLoadPlanner.Input(
            suggestedNextWeightKg: 67.5,
            lastWeightKg: 65,
            sessionMode: .standard,
            isInDeloadWeek: false,
            returningFromBreak: false,
            equipment: [.barbell],
            ceilings: [:],
            fallbackWeightKg: 20
        )
        XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(stored), 67.5)
        XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(stored), 67.5)

        for trend in [TrendDirection.stable, .increasing, .decreasing] {
            _ = trend
            XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(stored), 67.5)
        }

        var deload = stored
        deload.isInDeloadWeek = true
        XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(deload), 60)
        XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(deload), 60)

        var recovery = stored
        recovery.sessionMode = .recovery
        let recoveryOnce = SessionLoadPlanner.plannedWeightKg(recovery)
        XCTAssertEqual(recoveryOnce, SessionLoadPlanner.plannedWeightKg(recovery))
        XCTAssertEqual(
            recoveryOnce,
            GenerationConstants.Weight.roundToAvailable(67.5 * 0.7, equipment: [.barbell])
        )

        var reentry = stored
        reentry.returningFromBreak = true
        let reentryOnce = SessionLoadPlanner.plannedWeightKg(reentry)
        XCTAssertEqual(reentryOnce, SessionLoadPlanner.plannedWeightKg(reentry))
        XCTAssertEqual(
            reentryOnce,
            GenerationConstants.Weight.roundToAvailable(
                67.5 * GenerationConstants.Deload.reEntryWeightMultiplier,
                equipment: [.barbell]
            )
        )

        var loggedOnly = stored
        loggedOnly.suggestedNextWeightKg = nil
        XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(loggedOnly), 65)

        var cold = stored
        cold.suggestedNextWeightKg = nil
        cold.lastWeightKg = nil
        XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(cold), 20)
    }
}
