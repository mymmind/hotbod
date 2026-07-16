import Foundation

enum PendingPostSetAction: Equatable {
    case rest(seconds: Int, advanceAfter: Bool)
    case exerciseComplete
}

enum PostSetActionPlanner {
    static func action(
        allSetsDone: Bool,
        isWarmup: Bool,
        isCooldown: Bool,
        exerciseRestSeconds: Int
    ) -> PendingPostSetAction {
        if allSetsDone {
            return .exerciseComplete
        }

        let restSeconds: Int
        if isWarmup {
            restSeconds = GenerationConstants.Warmup.restSeconds
        } else if isCooldown {
            restSeconds = GenerationConstants.Cooldown.restSeconds
        } else {
            restSeconds = exerciseRestSeconds
        }
        return .rest(seconds: restSeconds, advanceAfter: false)
    }
}
