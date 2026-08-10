import Foundation

struct PhysiqueTrendAdaptResult: Hashable {
    var assessment: PhysiqueAssessment
    var didAdapt: Bool
    var reasons: [String]
}

enum PhysiqueTrendBiasAdapter {
    static let maxReasons = 3

    static func adapt(
        current: PhysiqueAssessment,
        previous: PhysiqueAssessment,
        diff: PhysiqueAssessmentDiff
    ) -> PhysiqueTrendAdaptResult {
        let baseGroups = PhysiqueTrainingBiasMerger.preferredGroups(
            from: current.developmentPriorities.map(\.muscle)
        )
        let boosts = collectBoosts(current: current, previous: previous, diff: diff)

        guard !boosts.reasons.isEmpty else {
            return PhysiqueTrendAdaptResult(
                assessment: current,
                didAdapt: false,
                reasons: []
            )
        }

        var adapted = current
        let reordered = reorderGroups(baseGroups: baseGroups, boostGroups: boosts.groups)
        adapted.trainingBias = PhysiqueTrainingBias(
            preferredMuscleGroups: reordered,
            rationale: boosts.reasons.joined(separator: " ")
        )
        adapted.trendAdaptation = PhysiqueTrendAdaptation(
            previousAssessmentId: previous.id,
            reasons: boosts.reasons
        )

        return PhysiqueTrendAdaptResult(
            assessment: adapted,
            didAdapt: true,
            reasons: boosts.reasons
        )
    }

    private struct BoostCollection {
        var groups: [MuscleGroup]
        var reasons: [String]
    }

    private static func collectBoosts(
        current: PhysiqueAssessment,
        previous: PhysiqueAssessment,
        diff: PhysiqueAssessmentDiff
    ) -> BoostCollection {
        var boostGroups: [MuscleGroup] = []
        var boostSet = Set<MuscleGroup>()
        var reasons: [String] = []

        for muscle in diff.priorityChanges.added {
            guard reasons.count < maxReasons else { break }
            for group in muscle.muscleGroups where !boostSet.contains(group) {
                boostSet.insert(group)
                boostGroups.append(group)
            }
            reasons.append("\(muscle.displayName) emphasized — priority appeared since last.")
        }

        let previousMuscles = previous.developmentPriorities.map(\.muscle)
        let currentMuscles = current.developmentPriorities.map(\.muscle)
        for (currentIndex, muscle) in currentMuscles.enumerated() {
            guard reasons.count < maxReasons else { break }
            guard let previousIndex = previousMuscles.firstIndex(of: muscle),
                  currentIndex < previousIndex else { continue }
            for group in muscle.muscleGroups where !boostSet.contains(group) {
                boostSet.insert(group)
                boostGroups.append(group)
            }
            reasons.append("\(muscle.displayName) moved up in focus order.")
        }

        if reasons.count < maxReasons,
           diff.visionTrends.contains(where: { $0.range(of: "wider", options: .caseInsensitive) != nil }),
           let shoulderPriority = current.developmentPriorities.first(where: {
               $0.muscle.muscleGroups.contains(.shoulders)
           }) {
            if !boostSet.contains(.shoulders) {
                boostSet.insert(.shoulders)
                boostGroups.append(.shoulders)
            }
            reasons.append("\(shoulderPriority.muscle.displayName) emphasized — visual trend wider.")
        }

        return BoostCollection(groups: boostGroups, reasons: reasons)
    }

    private static func reorderGroups(
        baseGroups: [MuscleGroup],
        boostGroups: [MuscleGroup]
    ) -> [MuscleGroup] {
        let boostSet = Set(boostGroups)
        return boostGroups + baseGroups.filter { !boostSet.contains($0) }
    }
}
