import Foundation

enum PhysiqueAssessmentSanitizer {
    private static let disallowedPatterns: [String] = [
        #"body\s*fat\s*%"#,
        #"body\s*fat\s*percent"#,
        #"\bgenetically\b"#,
        #"\bdiagnosed\s+with\b"#,
        #"\bmedical\s+diagnosis\b"#,
        #"\byou\s+have\s+(?:a\s+)?(?:clinical|medical)\b"#
    ]

    static func scrubFreeText(_ text: String) -> String {
        var result = text
        for pattern in disallowedPatterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return result
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func scrubFreeTexts(_ texts: [String]) -> [String] {
        texts.compactMap { text in
            let scrubbed = scrubFreeText(text)
            return scrubbed.isEmpty ? nil : scrubbed
        }
    }

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
                current: scrubFreeText(entry.current),
                priorityRank: confidence == .uncertain ? nil : entry.priorityRank,
                notes: scrubFreeText(entry.notes),
                confidence: confidence
            )
        }
    }

    static func sanitizeDevelopmentPriorities(
        _ priorities: [RemotePhysiqueDevelopmentPriorityPayload],
        muscleEntries: [PhysiqueMuscleEntry]
    ) -> [PhysiqueDevelopmentPriority] {
        let confidentMuscles = Set(
            muscleEntries
                .filter { $0.confidence != .uncertain }
                .map(\.muscle)
        )
        return priorities.compactMap { priority in
            guard let muscle = PhysiqueFocusMuscle(rawValue: priority.muscle) else { return nil }
            guard confidentMuscles.contains(muscle) else { return nil }
            let reason = scrubFreeText(priority.reason)
            guard !reason.isEmpty else { return nil }
            return PhysiqueDevelopmentPriority(muscle: muscle, reason: reason)
        }
    }

    static func map(
        _ payload: RemotePhysiqueAssessmentPayload,
        request: PhysiqueAssessmentRequest
    ) -> PhysiqueAssessment {
        let muscleEntries = sanitizeMuscleEntries(payload.muscleEntries)
        let sanitizedPriorities = sanitizeDevelopmentPriorities(
            payload.developmentPriorities,
            muscleEntries: muscleEntries
        )
        let preferredGroups = PhysiqueTrainingBiasMerger.preferredGroups(
            from: sanitizedPriorities.map(\.muscle)
        )
        let archetype = scrubFreeText(payload.physique.overallArchetype)
        let rationale = scrubFreeText(payload.trainingBias.rationale)
        let whyTodaySummary = scrubFreeText(payload.whyTodaySummary)

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
                overallArchetype: archetype.isEmpty
                    ? "Balanced build with modest shoulder-to-waist contrast"
                    : archetype,
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
                rationale: rationale.isEmpty ? "Prioritize balanced frame development." : rationale
            ),
            limitations: scrubFreeTexts(payload.limitations),
            confidenceBands: PhysiqueConfidenceBands(
                high: payload.confidenceBands.high,
                medium: payload.confidenceBands.medium,
                low: payload.confidenceBands.low
            ),
            source: .cloud,
            whyTodaySummary: whyTodaySummary.isEmpty
                ? "Bias training toward visible development priorities."
                : whyTodaySummary
        )
    }
}
