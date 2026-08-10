import Foundation

enum PhysiqueAssessmentDiffEngine {
    static func diff(
        previous: PhysiqueAssessment,
        current: PhysiqueAssessment,
        previousFrontRatio: Double? = nil,
        currentFrontRatio: Double? = nil,
        catalog: [String: PhysiqueArchetypeCatalogEntry] = PhysiqueArchetypeCatalogLoader.indexedById()
    ) -> PhysiqueAssessmentDiff {
        let buildChanges = buildChanges(previous: previous.physique, current: current.physique)
        let priorityChanges = priorityChanges(previous: previous, current: current)
        let directionChanges = directionChanges(previous: previous, current: current)
        let visionTrends = visionTrends(
            previousFrontRatio: previousFrontRatio,
            currentFrontRatio: currentFrontRatio
        )
        let hasMeaningfulChange = !buildChanges.isEmpty
            || !priorityChanges.added.isEmpty
            || !priorityChanges.removed.isEmpty
            || priorityChanges.reordered
            || !directionChanges.added.isEmpty
            || !directionChanges.removed.isEmpty
        let summaryLines = makeSummaryLines(
            buildChanges: buildChanges,
            priorityChanges: priorityChanges,
            directionChanges: directionChanges,
            catalog: catalog,
            hasMeaningfulChange: hasMeaningfulChange
        )

        return PhysiqueAssessmentDiff(
            previousId: previous.id,
            currentId: current.id,
            previousDate: previous.createdAt,
            currentDate: current.createdAt,
            buildChanges: buildChanges,
            priorityChanges: priorityChanges,
            directionChanges: directionChanges,
            visionTrends: visionTrends,
            summaryLines: summaryLines,
            hasMeaningfulChange: hasMeaningfulChange
        )
    }

    private static func buildChanges(
        previous: PhysiqueBuildSummary,
        current: PhysiqueBuildSummary
    ) -> [PhysiqueBuildFieldChange] {
        let buildFieldLabels: [(label: String, keyPath: KeyPath<PhysiqueBuildSummary, String>)] = [
            ("Frame", \.frameSize),
            ("Shoulder to waist", \.shoulderToWaist),
            ("Waist", \.waist),
            ("Torso", \.torso),
            ("Muscularity", \.muscularity),
            ("Leanness", \.leanness)
        ]

        var changes = buildFieldLabels.compactMap { label, keyPath -> PhysiqueBuildFieldChange? in
            let from = previous[keyPath: keyPath]
            let to = current[keyPath: keyPath]
            guard from != to else { return nil }
            return PhysiqueBuildFieldChange(field: label, from: from, to: to)
        }

        if previous.overallArchetype != current.overallArchetype, changes.isEmpty {
            changes.append(
                PhysiqueBuildFieldChange(
                    field: "Overall",
                    from: previous.overallArchetype,
                    to: current.overallArchetype
                )
            )
        }

        return changes
    }

    private static func priorityChanges(
        previous: PhysiqueAssessment,
        current: PhysiqueAssessment
    ) -> PhysiquePriorityChanges {
        let previousMuscles = previous.developmentPriorities.map(\.muscle)
        let currentMuscles = current.developmentPriorities.map(\.muscle)
        let previousSet = Set(previousMuscles)
        let currentSet = Set(currentMuscles)

        let added = currentMuscles.filter { !previousSet.contains($0) }
        let removed = previousMuscles.filter { !currentSet.contains($0) }
        let reordered = previousSet == currentSet && previousMuscles != currentMuscles

        return PhysiquePriorityChanges(added: added, removed: removed, reordered: reordered)
    }

    private static func directionChanges(
        previous: PhysiqueAssessment,
        current: PhysiqueAssessment
    ) -> PhysiqueDirectionChanges {
        let previousIds = Set(previous.physiqueDirections.map(\.archetypeId))
        let currentIds = Set(current.physiqueDirections.map(\.archetypeId))

        let added = current.physiqueDirections
            .map(\.archetypeId)
            .filter { !previousIds.contains($0) }
        let removed = previous.physiqueDirections
            .map(\.archetypeId)
            .filter { !currentIds.contains($0) }

        return PhysiqueDirectionChanges(added: added, removed: removed)
    }

    private static func visionTrends(
        previousFrontRatio: Double?,
        currentFrontRatio: Double?
    ) -> [String] {
        guard let previousFrontRatio, let currentFrontRatio else { return [] }
        let summary = BodyPhotoVisionMetrics.comparisonSummary(
            currentRatio: currentFrontRatio,
            previousRatio: previousFrontRatio,
            hasPrevious: true
        )
        return [summary]
    }

    private static func makeSummaryLines(
        buildChanges: [PhysiqueBuildFieldChange],
        priorityChanges: PhysiquePriorityChanges,
        directionChanges: PhysiqueDirectionChanges,
        catalog: [String: PhysiqueArchetypeCatalogEntry],
        hasMeaningfulChange: Bool
    ) -> [String] {
        guard hasMeaningfulChange else {
            return ["No meaningful change since last assessment."]
        }

        var lines: [String] = []
        let cap = 5

        for change in buildChanges {
            guard lines.count < cap else { break }
            lines.append("\(change.field) shifted: \(change.from) → \(change.to).")
        }

        if !priorityChanges.added.isEmpty, lines.count < cap {
            let names = priorityChanges.added.map(\.displayName).joined(separator: ", ")
            lines.append("Priority appeared: \(names).")
        }
        if !priorityChanges.removed.isEmpty, lines.count < cap {
            let names = priorityChanges.removed.map(\.displayName).joined(separator: ", ")
            lines.append("Priority dropped: \(names).")
        } else if priorityChanges.reordered, lines.count < cap {
            lines.append("Priority order shifted.")
        }

        if !directionChanges.added.isEmpty, lines.count < cap {
            let labels = catalogLabels(for: directionChanges.added, catalog: catalog)
            if !labels.isEmpty {
                lines.append("Direction appeared: \(labels.joined(separator: ", ")).")
            }
        }
        if !directionChanges.removed.isEmpty, lines.count < cap {
            let labels = catalogLabels(for: directionChanges.removed, catalog: catalog)
            if !labels.isEmpty {
                lines.append("Direction dropped: \(labels.joined(separator: ", ")).")
            }
        }

        return lines
    }

    private static func catalogLabels(
        for archetypeIds: [String],
        catalog: [String: PhysiqueArchetypeCatalogEntry]
    ) -> [String] {
        archetypeIds.compactMap { catalog[$0]?.genericLabel }
    }
}
