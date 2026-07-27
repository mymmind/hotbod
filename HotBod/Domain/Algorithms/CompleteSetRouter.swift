import Foundation

/// Where the primary set CTA should apply for the current exercise.
enum CompleteSetTarget: Equatable {
    /// Complete the active (next incomplete) set.
    case completeActive(setIndex: Int)
    /// Re-apply drafts onto an already-completed set the user is editing.
    case updateCompleted(setIndex: Int)
    /// Save drafts onto a future planned set without completing it.
    case updatePlanned(setIndex: Int)
    /// Nothing to do (no incomplete sets and no focused edit target).
    case none

    var isUpdate: Bool {
        switch self {
        case .updateCompleted, .updatePlanned: true
        case .completeActive, .none: false
        }
    }
}

/// Decides whether the primary CTA completes the active set or updates another row
/// the athlete focused (past completed or future planned).
enum CompleteSetRouter {
    /// - Parameters:
    ///   - plannedCount: Number of planned sets for the current exercise.
    ///   - completedSetIndexes: `setIndex` values already present in `completedSets`.
    ///   - focusedSetIndex: Planned index of the set whose input is focused, if any.
    static func target(
        plannedCount: Int,
        completedSetIndexes: Set<Int>,
        focusedSetIndex: Int?
    ) -> CompleteSetTarget {
        let activeIndex = (0..<plannedCount).first { !completedSetIndexes.contains($0) }

        guard let focused = focusedSetIndex, (0..<plannedCount).contains(focused) else {
            if let activeIndex { return .completeActive(setIndex: activeIndex) }
            return .none
        }

        if completedSetIndexes.contains(focused) {
            return .updateCompleted(setIndex: focused)
        }
        if focused == activeIndex {
            return .completeActive(setIndex: focused)
        }
        return .updatePlanned(setIndex: focused)
    }

    static func buttonTitle(for target: CompleteSetTarget) -> String {
        switch target {
        case .completeActive, .none:
            return "Complete Set"
        case .updateCompleted, .updatePlanned:
            return "Update Set"
        }
    }
}
