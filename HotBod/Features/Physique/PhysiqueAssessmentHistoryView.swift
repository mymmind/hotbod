import SwiftUI

struct PhysiqueAssessmentHistoryView: View {
    @Environment(AppEnvironment.self) private var environment

    private var history: [PhysiqueAssessment] {
        environment.physiqueAssessmentHistory
    }

    var body: some View {
        List {
            ForEach(Array(history.enumerated()), id: \.element.id) { index, assessment in
                NavigationLink {
                    PhysiqueAssessmentHistoryDetailView(
                        assessment: assessment,
                        historyIndex: index
                    )
                } label: {
                    historyRow(assessment, isCurrent: index == 0)
                }
                .accessibilityIdentifier("physique.history.\(assessment.id.uuidString)")
            }

            if history.count < 2 {
                Text("Reassess later to unlock change history.")
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.muted)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ForgeColors.background)
        .accessibilityIdentifier("physique.history.list")
        .navigationTitle("Assessment history")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await environment.loadActivePhysiqueAssessment()
        }
    }

    private func historyRow(_ assessment: PhysiqueAssessment, isCurrent: Bool) -> some View {
        HStack(alignment: .center, spacing: ForgeSpacing.s3) {
            VStack(alignment: .leading, spacing: ForgeSpacing.s1) {
                Text(assessment.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(ForgeTypography.body.weight(.semibold))
                Text(sourceLabel(for: assessment.source))
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.muted)
                if let topPriority = assessment.developmentPriorities.first {
                    Text(topPriority.muscle.displayName)
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.muted)
                }
            }
            Spacer()
            if isCurrent {
                Text("Current")
                    .font(ForgeTypography.caption.weight(.semibold))
                    .foregroundStyle(ForgeColors.textOnInverse)
                    .padding(.horizontal, ForgeSpacing.s2)
                    .padding(.vertical, ForgeSpacing.s1)
                    .background(ForgeColors.surfaceInverse)
                    .clipShape(RoundedRectangle.forge(ForgeRadius.sm))
            }
        }
        .padding(.vertical, ForgeSpacing.s1)
    }

    private func sourceLabel(for source: PhysiqueAssessmentSource) -> String {
        source == .cloud ? "Online" : "On-device"
    }
}

private struct PhysiqueAssessmentHistoryDetailView: View {
    @Environment(AppEnvironment.self) private var environment

    let assessment: PhysiqueAssessment
    let historyIndex: Int

    private var previousAssessment: PhysiqueAssessment? {
        let history = environment.physiqueAssessmentHistory
        let nextIndex = historyIndex + 1
        guard nextIndex < history.count else { return nil }
        return history[nextIndex]
    }

    private var compareDiff: PhysiqueAssessmentDiff? {
        guard let previous = previousAssessment else { return nil }
        return PhysiqueAssessmentDiffEngine.diff(
            previous: previous,
            current: assessment,
            previousFrontRatio: nil,
            currentFrontRatio: nil
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ForgeSpacing.s4) {
                if let diff = compareDiff {
                    compareCard(diff)
                }
                PhysiqueAssessmentReportContent(assessment: assessment)
            }
            .padding(ForgeSpacing.s5)
        }
        .background(ForgeColors.background)
        .navigationTitle(detailTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailTitle: String {
        assessment.createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    private func compareCard(_ diff: PhysiqueAssessmentDiff) -> some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                ForgeSectionHeader(
                    title: "Compared to previous",
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
    }

    private func dateRangeSubtitle(from previousDate: Date, to currentDate: Date) -> String {
        let format = Date.FormatStyle(date: .abbreviated, time: .omitted)
        return "\(previousDate.formatted(format)) → \(currentDate.formatted(format))"
    }
}

#Preview {
    NavigationStack {
        PhysiqueAssessmentHistoryView()
            .environment(AppEnvironment())
    }
}
