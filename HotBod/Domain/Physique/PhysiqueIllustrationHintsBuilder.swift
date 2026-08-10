import Foundation

enum PhysiqueIllustrationHintsBuilder {
    static func make(
        from assessment: PhysiqueAssessment,
        catalog: [String: PhysiqueArchetypeCatalogEntry] = PhysiqueArchetypeCatalogLoader.indexedById()
    ) -> PhysiqueIllustrationHints {
        let priorityMuscles = Array(assessment.developmentPriorities.prefix(3).map(\.muscle))

        var seenLabels = Set<String>()
        var directionGenericLabels: [String] = []
        let resolved = PhysiqueDirectionResolve.resolved(
            matches: assessment.physiqueDirections,
            catalog: catalog
        )
        for pair in resolved {
            let label = pair.entry.genericLabel
            guard !seenLabels.contains(label) else { continue }
            seenLabels.insert(label)
            directionGenericLabels.append(label)
            if directionGenericLabels.count >= 3 { break }
        }

        return PhysiqueIllustrationHints(
            priorityMuscles: priorityMuscles,
            directionGenericLabels: directionGenericLabels
        )
    }
}
