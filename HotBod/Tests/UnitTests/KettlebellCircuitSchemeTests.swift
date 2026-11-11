import XCTest
@testable import HotBod

final class KettlebellCircuitSchemeTests: XCTestCase {
    func testDefaultMatchesGenerationConstants() {
        let scheme = KettlebellCircuitScheme.default
        XCTAssertEqual(scheme.exerciseCount, GenerationConstants.KettlebellCircuit.exerciseCount)
        XCTAssertEqual(scheme.reps, GenerationConstants.KettlebellCircuit.reps)
        XCTAssertEqual(scheme.rounds, GenerationConstants.KettlebellCircuit.rounds)
        XCTAssertEqual(scheme.transitionRestSeconds, GenerationConstants.KettlebellCircuit.transitionRestSeconds)
        XCTAssertEqual(scheme.roundRestSeconds, GenerationConstants.KettlebellCircuit.roundRestSeconds)
    }

    func testClampedMapsToNearestAllowedOptions() {
        let raw = KettlebellCircuitScheme(
            exerciseCount: 2,
            reps: 9,
            rounds: 1,
            transitionRestSeconds: 12,
            roundRestSeconds: 70
        )
        let clamped = raw.clamped
        XCTAssertEqual(clamped.exerciseCount, 3)
        XCTAssertEqual(clamped.reps, 8)
        XCTAssertEqual(clamped.rounds, 3)
        XCTAssertEqual(clamped.transitionRestSeconds, 10)
        XCTAssertEqual(clamped.roundRestSeconds, 60)
    }

    func testProfileDecodeMissingSchemeUsesDefault() throws {
        var profile = UserProfile.empty()
        profile.kettlebellCircuitScheme = KettlebellCircuitScheme(
            exerciseCount: 3,
            reps: 4,
            rounds: 6,
            transitionRestSeconds: 20,
            roundRestSeconds: 90
        )
        let encoded = try JSONEncoder().encode(profile)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "kettlebellCircuitScheme")
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: stripped)
        XCTAssertEqual(decoded.kettlebellCircuitScheme, .default)
    }

    func testProfileRoundTripsCustomScheme() throws {
        var profile = UserProfile.empty()
        let scheme = KettlebellCircuitScheme(
            exerciseCount: 3,
            reps: 4,
            rounds: 6,
            transitionRestSeconds: 20,
            roundRestSeconds: 90
        )
        profile.kettlebellCircuitScheme = scheme
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
        XCTAssertEqual(decoded.kettlebellCircuitScheme, scheme)
    }
}
