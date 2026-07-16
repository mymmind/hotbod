import XCTest
@testable import HotBod

final class PostSetActionPlannerTests: XCTestCase {
    func testRegression_lastPlannedSetNeverStartsRest() {
        let action = PostSetActionPlanner.action(
            allSetsDone: true,
            isWarmup: false,
            isCooldown: false,
            exerciseRestSeconds: 120
        )
        XCTAssertEqual(action, .exerciseComplete)
    }

    func testRegression_lastWarmupSetNeverStartsRest() {
        let action = PostSetActionPlanner.action(
            allSetsDone: true,
            isWarmup: true,
            isCooldown: false,
            exerciseRestSeconds: 90
        )
        XCTAssertEqual(action, .exerciseComplete)
    }

    func testBetweenSetsUsesExerciseRest() {
        let action = PostSetActionPlanner.action(
            allSetsDone: false,
            isWarmup: false,
            isCooldown: false,
            exerciseRestSeconds: 90
        )
        XCTAssertEqual(action, .rest(seconds: 90, advanceAfter: false))
    }

    func testBetweenWarmupSetsUsesWarmupRest() {
        let action = PostSetActionPlanner.action(
            allSetsDone: false,
            isWarmup: true,
            isCooldown: false,
            exerciseRestSeconds: 90
        )
        XCTAssertEqual(action, .rest(seconds: GenerationConstants.Warmup.restSeconds, advanceAfter: false))
    }

    func testBetweenCooldownSetsUsesCooldownRest() {
        let action = PostSetActionPlanner.action(
            allSetsDone: false,
            isWarmup: false,
            isCooldown: true,
            exerciseRestSeconds: 90
        )
        XCTAssertEqual(action, .rest(seconds: GenerationConstants.Cooldown.restSeconds, advanceAfter: false))
    }
}
