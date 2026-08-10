import SwiftUI

struct PhysiqueAssessmentReportContent: View {
    let assessment: PhysiqueAssessment
    var sinceLastDiff: PhysiqueAssessmentDiff?

    private var resolvedDirections: [(match: PhysiqueArchetypeMatch, entry: PhysiqueArchetypeCatalogEntry)] {
        PhysiqueDirectionResolve.resolved(
            matches: assessment.physiqueDirections,
            catalog: PhysiqueArchetypeCatalogLoader.indexedById()
        )
    }

    var body: some View {
        VStack(spacing: ForgeSpacing.s4) {
            buildSummaryCard
            if let sinceLastDiff {
                sinceLastCard(sinceLastDiff)
            }
            developmentPrioritiesCard
            if !resolvedDirections.isEmpty {
                physiqueDirectionsSection(resolvedDirections)
            }
            whyTodayCard
        }
    }

    private func sinceLastCard(_ diff: PhysiqueAssessmentDiff) -> some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                ForgeSectionHeader(
                    title: "Since last assessment",
                    subtitle: dateRangeSubtitle(from: diff.previousDate, to: diff.currentDate)
                )
                ForEach(diff.summaryLines, id: \.self) { line in
                    Text(line)
                        .font(ForgeTypography.body)
                        .foregroundStyle(ForgeColors.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !diff.visionTrends.isEmpty {
                    Text("Visual trend")
                        .font(ForgeTypography.caption.weight(.semibold))
                        .foregroundStyle(ForgeColors.muted)
                    ForEach(diff.visionTrends, id: \.self) { trend in
                        Text(trend)
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .accessibilityIdentifier("physique.sinceLast")
    }

    private func dateRangeSubtitle(from previousDate: Date, to currentDate: Date) -> String {
        let format = Date.FormatStyle(date: .abbreviated, time: .omitted)
        return "\(previousDate.formatted(format)) → \(currentDate.formatted(format))"
    }

    private var buildSummaryCard: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                ForgeSectionHeader(
                    title: "Build Summary",
                    subtitle: assessment.physique.overallArchetype
                )
                summaryRow("Frame", assessment.physique.frameSize)
                summaryRow("Shoulder to waist", assessment.physique.shoulderToWaist)
                summaryRow("Muscularity", assessment.physique.muscularity)
                summaryRow("Leanness", assessment.physique.leanness)
            }
        }
    }

    private var developmentPrioritiesCard: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                ForgeSectionHeader(title: "Development Priorities", subtitle: "Ranked focus areas")
                ForEach(assessment.developmentPriorities, id: \.muscle) { priority in
                    VStack(alignment: .leading, spacing: ForgeSpacing.s1) {
                        Text(priority.muscle.displayName)
                            .font(ForgeTypography.body.weight(.semibold))
                        Text(priority.reason)
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("physique.priority.\(priority.muscle.rawValue)")
                    if priority.muscle != assessment.developmentPriorities.last?.muscle {
                        Divider()
                    }
                }
            }
        }
    }

    private var whyTodayCard: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                ForgeSectionHeader(title: "Why today’s training", subtitle: nil)
                Text(assessment.whyTodaySummary)
                    .font(ForgeTypography.body)
                    .foregroundStyle(ForgeColors.muted)
                    .lineLimit(5)
                if !assessment.trainingBias.rationale.isEmpty {
                    Text(assessment.trainingBias.rationale)
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.muted)
                }
            }
        }
    }

    private func physiqueDirectionsSection(
        _ resolvedDirections: [(match: PhysiqueArchetypeMatch, entry: PhysiqueArchetypeCatalogEntry)]
    ) -> some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                ForgeSectionHeader(
                    title: "Physique directions",
                    subtitle: "Reference directions for proportions and silhouette — not a prediction."
                )

                ForEach(resolvedDirections, id: \.match.archetypeId) { resolved in
                    VStack(alignment: .leading, spacing: ForgeSpacing.s1) {
                        Text(resolved.entry.genericLabel)
                            .font(ForgeTypography.body.weight(.semibold))
                        if let referenceLine = PhysiqueDirectionCopy.referenceLine(for: resolved.entry) {
                            Text(referenceLine)
                                .font(ForgeTypography.caption)
                                .foregroundStyle(ForgeColors.muted)
                        }
                        Text(resolved.match.similarityDimension)
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("physique.direction.\(resolved.match.archetypeId)")
                    if resolved.match.archetypeId != resolvedDirections.last?.match.archetypeId {
                        Divider()
                    }
                }

                Text(
                    "These are physique directions, not identity matches. "
                        + "Bone structure, insertions, and training response differ."
                )
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
            }
            .accessibilityIdentifier("physique.directions")
        }
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
            Spacer()
            Text(value)
                .font(ForgeTypography.body)
        }
    }
}

#Preview {
    ScrollView {
        PhysiqueAssessmentReportContent(assessment: PreviewFixtures.physiqueAssessment)
            .padding(ForgeSpacing.s5)
    }
    .background(ForgeColors.background)
}

private enum PreviewFixtures {
    static var physiqueAssessment: PhysiqueAssessment {
        PhysiqueAssessment(
            id: UUID(),
            createdAt: Date(),
            frontPhotoId: UUID(),
            backPhotoId: UUID(),
            sidePhotoId: nil,
            photoQuality: PhysiquePhotoQuality(
                anglesAvailable: ["front", "back"],
                lightingQuality: "Even",
                overallConfidence: 0.72
            ),
            physique: PhysiqueBuildSummary(
                overallArchetype: "Athletic build",
                frameSize: "Medium",
                shoulderToWaist: "Moderate contrast",
                waist: "Defined",
                torso: "Balanced",
                muscularity: "Moderate",
                leanness: "Moderate"
            ),
            muscleEntries: [],
            developmentPriorities: [
                PhysiqueDevelopmentPriority(muscle: .lateralDelts, reason: "Caps"),
                PhysiqueDevelopmentPriority(muscle: .lats, reason: "Width")
            ],
            trainingBias: PhysiqueTrainingBias(
                preferredMuscleGroups: [.shoulders, .back],
                rationale: "Frame balance."
            ),
            limitations: [],
            confidenceBands: PhysiqueConfidenceBands(high: [], medium: [], low: []),
            source: .onDevice,
            whyTodaySummary: "Bias shoulders and back."
        )
    }
}
