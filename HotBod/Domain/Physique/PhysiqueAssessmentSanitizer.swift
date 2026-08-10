import Foundation

enum PhysiqueAssessmentSanitizer {
    static func priorities(rawIds: [String], confidences: [String]) -> [PhysiqueFocusMuscle] {
        zip(rawIds, confidences).compactMap { id, confidence in
            guard confidence != PhysiqueObservationConfidence.uncertain.rawValue else { return nil }
            guard let muscle = PhysiqueFocusMuscle(rawValue: id) else { return nil }
            return muscle
        }
    }

    static func sanitizeMuscleEntries(
        _ entries: [RemotePhysiqueMuscleEntryPayload]
    ) -> [PhysiqueMuscleEntry] {
        entries.compactMap { entry in
            guard let muscle = PhysiqueFocusMuscle(rawValue: entry.muscle) else { return nil }
            let confidence = PhysiqueObservationConfidence(rawValue: entry.confidence) ?? .uncertain
            return PhysiqueMuscleEntry(
                muscle: muscle,
                current: entry.current,
                priorityRank: confidence == .uncertain ? nil : entry.priorityRank,
                notes: entry.notes,
                confidence: confidence
            )
        }
    }

    static func sanitizeDevelopmentPriorities(
        _ priorities: [RemotePhysiqueDevelopmentPriorityPayload],
        excluding uncertainMuscles: Set<PhysiqueFocusMuscle>
    ) -> [PhysiqueDevelopmentPriority] {
        priorities.compactMap { priority in
            guard let muscle = PhysiqueFocusMuscle(rawValue: priority.muscle) else { return nil }
            guard !uncertainMuscles.contains(muscle) else { return nil }
            return PhysiqueDevelopmentPriority(muscle: muscle, reason: priority.reason)
        }
    }

    static func map(
        _ payload: RemotePhysiqueAssessmentPayload,
        request: PhysiqueAssessmentRequest
    ) -> PhysiqueAssessment {
        let muscleEntries = sanitizeMuscleEntries(payload.muscleEntries)
        let uncertainMuscles = Set(
            muscleEntries
                .filter { $0.confidence == .uncertain }
                .map(\.muscle)
        )
        let sanitizedPriorities = sanitizeDevelopmentPriorities(
            payload.developmentPriorities,
            excluding: uncertainMuscles
        )
        let preferredGroups = PhysiqueTrainingBiasMerger.preferredGroups(
            from: sanitizedPriorities.map(\.muscle)
        )

        return PhysiqueAssessment(
            id: UUID(),
            createdAt: Date(),
            frontPhotoId: request.selection.front.id,
            backPhotoId: request.selection.back.id,
            sidePhotoId: request.selection.side?.id,
            photoQuality: PhysiquePhotoQuality(
                anglesAvailable: payload.photoQuality.anglesAvailable,
                lightingQuality: payload.photoQuality.lightingQuality,
                overallConfidence: payload.photoQuality.overallConfidence
            ),
            physique: PhysiqueBuildSummary(
                overallArchetype: payload.physique.overallArchetype,
                frameSize: payload.physique.frameSize,
                shoulderToWaist: payload.physique.shoulderToWaist,
                waist: payload.physique.waist,
                torso: payload.physique.torso,
                muscularity: payload.physique.muscularity,
                leanness: payload.physique.leanness
            ),
            muscleEntries: muscleEntries,
            developmentPriorities: sanitizedPriorities,
            trainingBias: PhysiqueTrainingBias(
                preferredMuscleGroups: preferredGroups,
                rationale: payload.trainingBias.rationale
            ),
            limitations: payload.limitations,
            confidenceBands: PhysiqueConfidenceBands(
                high: payload.confidenceBands.high,
                medium: payload.confidenceBands.medium,
                low: payload.confidenceBands.low
            ),
            source: .cloud,
            whyTodaySummary: payload.whyTodaySummary
        )
    }
}
