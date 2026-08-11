import Foundation

struct PhysiqueSplitSuggestion: Equatable, Sendable {
    var assessmentId: UUID
    var from: TrainingSplit
    var to: TrainingSplit
    var scoreCurrent: Int
    var scoreCandidate: Int
    var highlightMuscles: [MuscleGroup]
}

enum PhysiqueSplitSuggestionEvaluator {
    private static let millipointBudget = 1000

    static func suggestedSplit(forDaysPerWeek days: Int) -> TrainingSplit {
        switch days {
        case ...3: .fullBody
        case 4: .upperLower
        case 5...6: .pushPullLegs
        default: .adaptive
        }
    }

    static func coverageScore(
        split: TrainingSplit,
        daysPerWeek: Int,
        preferred: [MuscleGroup]
    ) -> Int {
        guard !preferred.isEmpty else { return 0 }
        var total = 0
        for muscles in muscleSets(split: split, daysPerWeek: daysPerWeek) {
            let weight = millipointBudget / max(muscles.count, 1)
            for m in preferred where muscles.contains(m) {
                total += weight
            }
        }
        return total
    }

    static func evaluate(
        assessmentId: UUID,
        currentSplit: TrainingSplit,
        daysPerWeek: Int,
        preferredMuscleGroups: [MuscleGroup],
        avoidedMuscleGroups: [MuscleGroup],
        dismissedAssessmentId: UUID?
    ) -> PhysiqueSplitSuggestion? {
        if dismissedAssessmentId == assessmentId { return nil }
        let preferred = PhysiqueTrainingBiasMerger.physiquePreferredMuscleGroups(
            assessmentBias: preferredMuscleGroups,
            avoided: avoidedMuscleGroups
        )
        guard !preferred.isEmpty else { return nil }
        let candidate = suggestedSplit(forDaysPerWeek: daysPerWeek)
        guard candidate != currentSplit else { return nil }
        let scoreCurrent = coverageScore(
            split: currentSplit, daysPerWeek: daysPerWeek, preferred: preferred
        )
        let scoreCandidate = coverageScore(
            split: candidate, daysPerWeek: daysPerWeek, preferred: preferred
        )
        guard scoreCandidate > scoreCurrent else { return nil }
        return PhysiqueSplitSuggestion(
            assessmentId: assessmentId,
            from: currentSplit,
            to: candidate,
            scoreCurrent: scoreCurrent,
            scoreCandidate: scoreCandidate,
            highlightMuscles: highlightMuscles(
                preferred: preferred,
                currentSplit: currentSplit,
                candidate: candidate,
                daysPerWeek: daysPerWeek
            )
        )
    }

    // MARK: Private

    private static func muscleSets(
        split: TrainingSplit,
        daysPerWeek: Int
    ) -> [Set<MuscleGroup>] {
        let n = max(1, daysPerWeek)
        let sequence = TrainingSchedule.splitSequence(for: split)
        if sequence.isEmpty {
            let adaptive = Set(TrainingSchedule.muscles(for: .upper))
                .union(TrainingSchedule.muscles(for: .lower))
            return Array(repeating: adaptive, count: n)
        }
        return (0..<n).map { Set(TrainingSchedule.muscles(for: sequence[$0 % sequence.count])) }
    }

    private static func highlightMuscles(
        preferred: [MuscleGroup],
        currentSplit: TrainingSplit,
        candidate: TrainingSplit,
        daysPerWeek: Int
    ) -> [MuscleGroup] {
        let deltas: [(MuscleGroup, Int)] = preferred.map { m in
            let delta = coverageScore(split: candidate, daysPerWeek: daysPerWeek, preferred: [m])
                - coverageScore(split: currentSplit, daysPerWeek: daysPerWeek, preferred: [m])
            return (m, delta)
        }
        let positive = deltas.filter { $0.1 > 0 }.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            let li = preferred.firstIndex(of: lhs.0) ?? 0
            let ri = preferred.firstIndex(of: rhs.0) ?? 0
            return li < ri
        }
        let picked = Array(positive.prefix(2).map(\.0))
        return picked.isEmpty ? Array(preferred.prefix(2)) : picked
    }
}
