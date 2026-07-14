import XCTest
@testable import HotBod

final class ScheduleRotationPropertyTests: XCTestCase {
  func testSplitRotationPreservesValidFocusSequence() async throws {
    let splits: [TrainingSplit] = [.pushPullLegs, .upperLower, .fullBody, .bodyPart]
    var rng = SeededRandomNumberGenerator(seed: 509)

    for iteration in 0..<PropertyTestHelpers.iterationCount {
      let split = splits[Int.random(in: 0..<splits.count, using: &rng)]
      let sequence = TrainingSchedule.splitSequence(for: split)
      var state = TrainingProgramState()
      let advanceCount = Int.random(in: 0...max(sequence.count * 2, 1), using: &rng)

      for _ in 0..<advanceCount {
        TrainingSchedule.advanceRotation(state: &state, split: split)
      }

      if sequence.isEmpty {
        XCTAssertEqual(state.splitDayIndex, 0, "Iteration \(iteration)")
        XCTAssertNil(TrainingSchedule.currentSplitFocus(state: state, split: split))
      } else {
        XCTAssertEqual(
          TrainingSchedule.currentSplitFocus(state: state, split: split),
          sequence[state.splitDayIndex % sequence.count],
          "Iteration \(iteration)"
        )
      }
    }
  }
}
