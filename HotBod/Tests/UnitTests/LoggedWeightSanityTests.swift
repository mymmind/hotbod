import XCTest
@testable import HotBod

final class LoggedWeightSanityTests: XCTestCase {
    func testOkWithinJumpMultiplierVsLast() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 100,
            lastWeightKg: 80,
            plannedWeightKg: 80
        )
        XCTAssertEqual(outcome, .ok)
    }

    func testSoftWarningVsLastWeight() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 150,
            lastWeightKg: 80,
            plannedWeightKg: 80
        )
        XCTAssertEqual(outcome, .softWarning(baselineKg: 80))
    }

    func testSoftWarningUsesPlannedWhenNoLast() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 150,
            lastWeightKg: nil,
            plannedWeightKg: 80
        )
        XCTAssertEqual(outcome, .softWarning(baselineKg: 80))
    }

    func testPrefersLastOverPlannedForBaseline() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 200,
            lastWeightKg: 100,
            plannedWeightKg: 50
        )
        // 200 > 100 * 1.5 → soft vs last (not vs planned 50)
        XCTAssertEqual(outcome, .softWarning(baselineKg: 100))
    }

    func testNoSoftWarningWithoutBaseline() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 300,
            lastWeightKg: nil,
            plannedWeightKg: nil
        )
        XCTAssertEqual(outcome, .ok)
    }

    func testIgnoresNonPositiveBaselines() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 300,
            lastWeightKg: 0,
            plannedWeightKg: -10
        )
        XCTAssertEqual(outcome, .ok)
    }

    func testHardBlockNegative() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: -5,
            lastWeightKg: 80,
            plannedWeightKg: 80
        )
        XCTAssertEqual(outcome, .hardBlock(.negative))
    }

    func testHardBlockAboveAbsoluteMax() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 400.1,
            lastWeightKg: 80,
            plannedWeightKg: 80
        )
        XCTAssertEqual(outcome, .hardBlock(.aboveAbsoluteMax))
    }

    func testExactMaxIsOk() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 400,
            lastWeightKg: nil,
            plannedWeightKg: nil
        )
        XCTAssertEqual(outcome, .ok)
    }

    func testHardWinsOverSoft() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 800,
            lastWeightKg: 80,
            plannedWeightKg: 80
        )
        XCTAssertEqual(outcome, .hardBlock(.aboveAbsoluteMax))
    }

    func testRegression_absurdLoggedWeight() {
        // Fat-finger 800 kg must never be soft-overrideable.
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 800,
            lastWeightKg: 60,
            plannedWeightKg: 60
        )
        guard case .hardBlock(.aboveAbsoluteMax) = outcome else {
            return XCTFail("Expected hard block for 800 kg, got \(outcome)")
        }
    }
}
