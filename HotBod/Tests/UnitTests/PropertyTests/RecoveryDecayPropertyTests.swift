import XCTest
@testable import HotBod

final class RecoveryDecayPropertyTests: XCTestCase {
  func testRecoveryDecayNeverDecreasesAndCapsAtOneHundred() async throws {
    var rng = SeededRandomNumberGenerator(seed: 907)

    for iteration in 0..<PropertyTestHelpers.iterationCount {
      let experience = ExperienceLevel.allCases[Int.random(in: 0..<ExperienceLevel.allCases.count, using: &rng)]
      let now = Date(timeIntervalSince1970: Double.random(in: 1_600_000_000...1_800_000_000, using: &rng))
      let hoursAgo = Double.random(in: 0...240, using: &rng)
      let lastDecay = now.addingTimeInterval(-hoursAgo * 3600)

      var states = RecoveryCalculator.defaultStates()
      for index in states.indices {
        states[index].recoveryPercentage = Double.random(in: 10...95, using: &rng)
      }

      let before = states.map(\.recoveryPercentage)
      let decay = RecoveryCalculator.decayRecovery(
        states: states,
        experienceLevel: experience,
        lastDecayAppliedAt: lastDecay,
        now: now
      )

      for (beforeValue, afterState) in zip(before, decay.states) {
        XCTAssertGreaterThanOrEqual(afterState.recoveryPercentage, beforeValue, "Iteration \(iteration)")
        XCTAssertLessThanOrEqual(afterState.recoveryPercentage, 100, "Iteration \(iteration)")
      }
    }
  }
}
