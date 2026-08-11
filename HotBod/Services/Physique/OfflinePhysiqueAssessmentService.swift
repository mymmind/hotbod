import Foundation

struct OfflinePhysiqueAssessmentService: PhysiqueAssessmentServing {
    private static let visualOnlyDisclaimer = "Visual estimate only — not a medical assessment."

    func assess(_ request: PhysiqueAssessmentRequest) async throws -> PhysiqueAssessment {
        let hasSide = request.sideMetrics != nil
        let ratio = request.frontMetrics.shoulderWaistRatio
        let priorityMuscles = Self.priorityMuscles(hasSide: hasSide)
        let preferredGroups = PhysiqueTrainingBiasMerger.preferredGroups(from: priorityMuscles)
        let overallConfidence = Self.overallConfidence(
            front: request.frontMetrics,
            back: request.backMetrics,
            side: request.sideMetrics
        )
        let summary = Self.buildSummary(ratio: ratio)
        let priorities = Self.developmentPriorities(for: priorityMuscles)

        var limitations = [Self.visualOnlyDisclaimer]
        if !hasSide {
            limitations.append("Side photo missing; rear detail may be less reliable.")
        }

        return PhysiqueAssessment(
            id: UUID(),
            createdAt: Date(),
            frontPhotoId: request.selection.front.id,
            backPhotoId: request.selection.back?.id,
            sidePhotoId: request.selection.side?.id,
            photoQuality: PhysiquePhotoQuality(
                anglesAvailable: Self.anglesAvailable(hasSide: hasSide),
                lightingQuality: Self.lightingQuality(
                    front: request.frontMetrics,
                    back: request.backMetrics,
                    side: request.sideMetrics
                ),
                overallConfidence: overallConfidence
            ),
            physique: summary,
            muscleEntries: Self.muscleEntries(priorityMuscles: priorityMuscles, hasSide: hasSide),
            developmentPriorities: priorities,
            trainingBias: PhysiqueTrainingBias(
                preferredMuscleGroups: preferredGroups,
                rationale: Self.trainingRationale(for: preferredGroups)
            ),
            limitations: limitations,
            confidenceBands: Self.confidenceBands(hasSide: hasSide),
            source: .onDevice,
            whyTodaySummary: Self.whyTodaySummary(from: preferredGroups),
            physiqueDirections: PhysiqueArchetypeMatcher.match(
                physique: summary,
                priorities: priorities,
                overallConfidence: overallConfidence
            )
        )
    }

    private static func priorityMuscles(hasSide: Bool) -> [PhysiqueFocusMuscle] {
        if hasSide {
            return [.lateralDelts, .lats, .upperChest, .rearDelts]
        }
        return [.lateralDelts, .lats, .upperChest, .traps]
    }

    private static func overallArchetype(ratio: Double?) -> String {
        guard let ratio else {
            return "Balanced build with modest shoulder-to-waist contrast"
        }
        if ratio >= 1.3 {
            return "Athletic build with favorable shoulder-to-waist contrast"
        }
        if ratio >= 1.15 {
            return "Athletic build with moderate shoulder-to-waist contrast"
        }
        if ratio >= 1.0 {
            return "Balanced build with modest shoulder-to-waist contrast"
        }
        return "Compact build with limited shoulder-to-waist contrast"
    }

    private static func shoulderToWaistLabel(ratio: Double?) -> String {
        guard let ratio else { return "Moderate contrast" }
        if ratio >= 1.3 { return "Favorable contrast" }
        if ratio >= 1.15 { return "Moderate contrast" }
        if ratio >= 1.0 { return "Modest contrast" }
        return "Limited contrast"
    }

    private static func buildSummary(ratio: Double?) -> PhysiqueBuildSummary {
        PhysiqueBuildSummary(
            overallArchetype: overallArchetype(ratio: ratio),
            frameSize: "Medium",
            shoulderToWaist: shoulderToWaistLabel(ratio: ratio),
            waist: "Defined",
            torso: "Balanced",
            muscularity: "Moderate",
            leanness: "Moderate"
        )
    }

    private static func anglesAvailable(hasSide: Bool) -> [String] {
        var angles = ["front", "back"]
        if hasSide {
            angles.append("side")
        }
        return angles
    }

    private static func lightingQuality(
        front: BodyPhotoAnalysis,
        back: BodyPhotoAnalysis,
        side: BodyPhotoAnalysis?
    ) -> String {
        var scores = [front.lightingScore, back.lightingScore]
        if let side {
            scores.append(side.lightingScore)
        }
        let average = scores.reduce(0, +) / Double(scores.count)
        if average >= 0.8 { return "Even" }
        if average >= 0.65 { return "Adequate" }
        return "Uneven"
    }

    private static func overallConfidence(
        front: BodyPhotoAnalysis,
        back: BodyPhotoAnalysis,
        side: BodyPhotoAnalysis?
    ) -> Double {
        let frontBackScores = [
            front.poseConfidence, front.lightingScore, front.framingScore,
            back.poseConfidence, back.lightingScore, back.framingScore
        ]
        let base = frontBackScores.reduce(0, +) / Double(frontBackScores.count)
        if side != nil {
            return min(1.0, max(base + 0.12, 0.82))
        }
        return base
    }

    private static func muscleEntries(
        priorityMuscles: [PhysiqueFocusMuscle],
        hasSide: Bool
    ) -> [PhysiqueMuscleEntry] {
        var entries = priorityMuscles.enumerated().map { index, muscle in
            PhysiqueMuscleEntry(
                muscle: muscle,
                current: "Moderate \(muscle.displayName.lowercased()) development",
                priorityRank: index + 1,
                notes: notes(for: muscle, hasSide: hasSide),
                confidence: confidence(for: muscle, hasSide: hasSide)
            )
        }

        if !hasSide {
            entries.append(
                PhysiqueMuscleEntry(
                    muscle: .rearDelts,
                    current: "Rear delt detail unclear without side angle",
                    priorityRank: nil,
                    notes: "Side photo needed for reliable rear delt ranking",
                    confidence: .uncertain
                )
            )
        }

        return entries
    }

    private static func confidence(for muscle: PhysiqueFocusMuscle, hasSide: Bool) -> PhysiqueObservationConfidence {
        switch muscle {
        case .lateralDelts, .lats, .upperChest:
            return .high
        case .rearDelts:
            return hasSide ? .medium : .uncertain
        case .traps:
            return .medium
        default:
            return .medium
        }
    }

    private static func notes(for muscle: PhysiqueFocusMuscle, hasSide: Bool) -> String {
        switch muscle {
        case .lateralDelts:
            return "Visible from front angle"
        case .lats:
            return "Back width supports V-taper balance"
        case .upperChest:
            return "Upper chest fills the clavicular line"
        case .rearDelts:
            return hasSide ? "Side angle improves rear delt visibility" : "Limited without side photo"
        case .traps:
            return "Upper back detail inferred from back photo"
        default:
            return "Visual estimate from available angles"
        }
    }

    private static func developmentPriorities(for muscles: [PhysiqueFocusMuscle]) -> [PhysiqueDevelopmentPriority] {
        muscles.map { muscle in
            PhysiqueDevelopmentPriority(
                muscle: muscle,
                reason: priorityReason(for: muscle)
            )
        }
    }

    private static func priorityReason(for muscle: PhysiqueFocusMuscle) -> String {
        switch muscle {
        case .lateralDelts:
            return "Side delt width improves shoulder line."
        case .lats:
            return "Lat width supports V-taper balance."
        case .upperChest:
            return "Upper chest fills the clavicular line."
        case .rearDelts:
            return "Rear delts balance pressing volume."
        case .traps:
            return "Trap development supports upper back presence."
        default:
            return "Supports balanced visual development."
        }
    }

    private static func trainingRationale(for groups: [MuscleGroup]) -> String {
        let names = groups.prefix(3).map { $0.displayName.lowercased() }.joined(separator: ", ")
        return "Prioritize \(names) for frame balance from photo angles."
    }

    private static func whyTodaySummary(from groups: [MuscleGroup]) -> String {
        let topThree = Array(groups.prefix(3))
        guard !topThree.isEmpty else {
            return "Bias training toward balanced upper-body development."
        }
        let names = formattedGroupList(topThree.map { $0.displayName.lowercased() })
        return "Bias \(names) to improve visual frame balance."
    }

    private static func formattedGroupList(_ names: [String]) -> String {
        switch names.count {
        case 0:
            return ""
        case 1:
            return names[0]
        case 2:
            return "\(names[0]) and \(names[1])"
        default:
            let head = names.dropLast().joined(separator: ", ")
            return "\(head), and \(names.last!)"
        }
    }

    private static func confidenceBands(hasSide: Bool) -> PhysiqueConfidenceBands {
        if hasSide {
            return PhysiqueConfidenceBands(
                high: ["Front shoulder line", "Back lat spread"],
                medium: ["Rear delt detail", "Upper chest line"],
                low: ["Lower body detail from photos"]
            )
        }
        return PhysiqueConfidenceBands(
            high: ["Front shoulder line"],
            medium: ["Back lat spread"],
            low: ["Rear delt detail without side photo"]
        )
    }
}
