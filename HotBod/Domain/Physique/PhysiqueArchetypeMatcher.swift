import Foundation

enum PhysiqueArchetypeMatcher {
    private static let fallbackSimilarityDimension = "Proportional similarity on visible frame traits."

    private static let hintStopwords: Set<String> = [
        "about", "after", "along", "also", "among", "another", "around", "across",
        "before", "being", "between", "both", "build", "could", "during", "each",
        "from", "have", "into", "just", "like", "look", "made", "make", "more",
        "most", "much", "only", "other", "over", "same", "should", "some", "such",
        "than", "that", "their", "them", "then", "there", "these", "they", "this",
        "those", "through", "under", "very", "were", "what", "when", "where",
        "which", "while", "will", "with", "within", "without", "would", "your"
    ]

    static func match(
        physique: PhysiqueBuildSummary,
        priorities: [PhysiqueDevelopmentPriority],
        catalog: [PhysiqueArchetypeCatalogEntry] = PhysiqueArchetypeCatalogLoader.load(),
        maxCount: Int = 3,
        overallConfidence: Double
    ) -> [PhysiqueArchetypeMatch] {
        let signalTags = buildSignalTags(physique: physique, priorities: priorities)
        let overallArchetype = physique.overallArchetype.lowercased()

        let scored = catalog.map { entry -> (entry: PhysiqueArchetypeCatalogEntry, score: Int) in
            let tagOverlap = entry.tags.filter { signalTags.contains($0) }.count
            let hintBonus = entry.similarityHints.contains { hint in
                similarityHintMatchesArchetype(hint, overallArchetype: overallArchetype)
            } ? 1 : 0
            return (entry, tagOverlap + hintBonus)
        }
        .filter { $0.score > 0 }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.entry.id < rhs.entry.id
        }

        let limit = overallConfidence < 0.55 ? 1 : maxCount
        return Array(scored.prefix(limit)).enumerated().map { index, item in
            PhysiqueArchetypeMatch(
                archetypeId: item.entry.id,
                rank: index + 1,
                similarityDimension: similarityDimension(for: item.entry),
                confidence: matchConfidence(for: item.score)
            )
        }
    }

    private static func buildSignalTags(
        physique: PhysiqueBuildSummary,
        priorities: [PhysiqueDevelopmentPriority]
    ) -> Set<String> {
        var tags: Set<String> = ["athletic"]

        let shoulderToWaist = physique.shoulderToWaist.lowercased()
        if shoulderToWaist.contains("favorable") || shoulderToWaist.contains("strong") {
            tags.insert("v_taper")
        }

        if physique.leanness.lowercased().contains("lean") {
            tags.insert("lean")
        }

        let priorityMuscles = Set(priorities.map(\.muscle))
        if priorityMuscles.contains(.lateralDelts) {
            tags.insert("delts")
            tags.insert("v_taper")
        }
        if priorityMuscles.contains(.lats) {
            tags.insert("lats")
            tags.insert("v_taper")
        }

        let muscularity = physique.muscularity.lowercased()
        if muscularity.contains("high") || muscularity.contains("dense") {
            tags.insert("muscular")
        }

        let archetypeText = physique.overallArchetype.lowercased()
        if physique.frameSize.lowercased().contains("compact") || archetypeText.contains("compact") {
            tags.insert("compact")
        }

        return tags
    }

    private static func similarityHintMatchesArchetype(_ hint: String, overallArchetype: String) -> Bool {
        let keywords = hint
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 5 && !hintStopwords.contains($0) }
        return keywords.contains { overallArchetype.contains($0) }
    }

    private static func similarityDimension(for entry: PhysiqueArchetypeCatalogEntry) -> String {
        guard let firstHint = entry.similarityHints.first else {
            return fallbackSimilarityDimension
        }
        let scrubbed = PhysiqueAssessmentSanitizer.scrubFreeText(firstHint)
        return scrubbed.isEmpty ? fallbackSimilarityDimension : scrubbed
    }

    private static func matchConfidence(for score: Int) -> PhysiqueObservationConfidence {
        if score >= 3 { return .high }
        if score == 2 { return .medium }
        return .low
    }
}
