import SwiftUI

enum ForgeHeroTitleStyle {
    case display
    case metric
}

struct ForgeHeroTitleAccessory {
    let systemImage: String
    let accessibilityLabel: String
    var accessibilityIdentifier: String? = nil
    let action: () -> Void
}

struct ForgeHeroCard: View {
    let eyebrow: String
    let title: String
    var badge: String? = nil
    var durationMinutes: Int? = nil
    var focusLine: String? = nil
    var exerciseLine: String? = nil
    var safetyNotes: [String] = []
    var completed: Bool = false
    var completionMetrics: [(label: String, value: String)] = []
    var footerLine: String? = nil
    var progress: Double? = nil
    var inverted: Bool = true
    var fullBleedTop: Bool = false
    var ambientGlow: Bool = false
    var statPills: [String] = []
    var accent: Color = ForgeColors.accent
    var titleStyle: ForgeHeroTitleStyle = .display
    var titlePulseValue: Double? = nil
    var titleAccessory: ForgeHeroTitleAccessory? = nil
    var loadingSecondaryTitle: String? = nil
    var primaryAction: (title: String, action: () -> Void)? = nil
    var secondaryActions: [(title: String, action: () -> Void)] = []
    var primaryAccessibilityIdentifier: String? = nil
    var secondaryAccessibilityIdentifiers: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s4) {
            HStack(alignment: .firstTextBaseline) {
                Text(eyebrow.uppercased())
                    .font(ForgeTypography.caption)
                    .tracking(2)
                    .foregroundStyle(eyebrowColor)
                    .opacity(completed ? 0.7 : 1)
                Spacer()
                if let badge {
                    Text(badge.uppercased())
                        .font(ForgeTypography.caption)
                        .tracking(2)
                        .foregroundStyle(ForgeColors.accentGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(Rectangle().stroke(ForgeColors.accentGreen.opacity(0.5), lineWidth: 1))
                } else if let durationMinutes, !completed {
                    Text("\(durationMinutes) min")
                        .font(ForgeTypography.monoMetric)
                        .foregroundStyle(accent)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(titleStyle == .metric ? ForgeTypography.heroMetric : ForgeTypography.displayAthletic)
                    .foregroundStyle(completed ? secondaryForeground.opacity(0.75) : primaryForeground)
                    .contentTransition(.numericText())
                    .modifier(TitlePulseModifier(value: titlePulseValue))
                    .fixedSize(horizontal: false, vertical: true)

                if let titleAccessory {
                    Button(action: titleAccessory.action) {
                        Image(systemName: titleAccessory.systemImage)
                            .font(.system(size: ForgeIcons.tab, weight: .bold))
                            .foregroundStyle(accent)
                            .padding(ForgeSpacing.s3 - 2)
                            .background(Circle().fill(accent.opacity(0.16)))
                    }
                    .buttonStyle(.plain)
                    .frame(width: ForgeTarget.min, height: ForgeTarget.min)
                    .contentShape(Rectangle())
                    .accessibilityLabel(titleAccessory.accessibilityLabel)
                    .accessibilityIdentifier(titleAccessory.accessibilityIdentifier ?? "")
                }
            }

            if !statPills.isEmpty {
                HStack(spacing: 8) {
                    ForEach(statPills, id: \.self) { pill in
                        ForgePill(label: pill, inverted: inverted)
                    }
                }
            }

            if let progress {
                ForgeProgressBar(progress: progress, inverted: inverted, fill: accent)
            }

            if !completionMetrics.isEmpty {
                completionMetricsRow
            }

            if let focusLine, !focusLine.isEmpty {
                Text(focusLine)
                    .font(ForgeTypography.body)
                    .foregroundStyle(completed ? secondaryForeground.opacity(0.7) : secondaryForeground)
            }

            if let exerciseLine, !exerciseLine.isEmpty {
                Text(exerciseLine)
                    .font(ForgeTypography.caption)
                    .foregroundStyle(completed ? secondaryForeground.opacity(0.6) : secondaryForeground.opacity(0.85))
                    .lineLimit(2)
            }

            if !safetyNotes.isEmpty, !completed {
                Text(safetyNotes.joined(separator: " · "))
                    .font(ForgeTypography.caption)
                    .foregroundStyle(secondaryForeground.opacity(0.65))
            }

            if let footerLine {
                Text(footerLine)
                    .font(ForgeTypography.caption)
                    .foregroundStyle(inverted ? secondaryForeground.opacity(0.65) : ForgeColors.muted)
            }

            actionButtons
        }
        .padding(.horizontal, ForgeSpacing.s5)
        .padding(.bottom, ForgeSpacing.s8)
        .padding(.top, fullBleedTop ? ForgeSpacing.s5 : ForgeSpacing.s8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .safeAreaPadding(.top, fullBleedTop ? 4 : 0)
        .background {
            let fill = inverted ? ForgeColors.surfaceInverse : ForgeColors.surface
            ZStack {
                if ambientGlow && inverted && !completed {
                    RadialGradient(
                        colors: [accent.opacity(0.45), .clear],
                        center: .topTrailing,
                        startRadius: 8,
                        endRadius: 220
                    )
                }
                if fullBleedTop {
                    fill.ignoresSafeArea(edges: .top)
                } else {
                    fill
                }
            }
        }
    }

    private var eyebrowColor: Color {
        if completed { return secondaryForeground }
        return inverted ? accent : ForgeColors.muted
    }

    private var primaryForeground: Color {
        inverted ? ForgeColors.surface : ForgeColors.foreground
    }

    private var secondaryForeground: Color {
        inverted ? ForgeColors.surface : ForgeColors.muted
    }

    @ViewBuilder
    private var completionMetricsRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(completionMetrics.enumerated()), id: \.offset) { index, metric in
                if index > 0 {
                    Rectangle()
                        .fill(secondaryForeground.opacity(0.25))
                        .frame(width: 1, height: 36)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(metric.label.uppercased())
                        .font(ForgeTypography.caption)
                        .tracking(1.5)
                        .foregroundStyle(secondaryForeground.opacity(0.65))
                    Text(metric.value)
                        .font(ForgeTypography.monoMetric)
                        .foregroundStyle(completed ? ForgeColors.accentGreen : primaryForeground)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if let primaryAction {
            ForgeButton(
                title: primaryAction.title,
                style: inverted && !completed ? .accent : (inverted ? .inverse : .primary),
                accessibilityIdentifier: primaryAccessibilityIdentifier,
                action: primaryAction.action
            )
        }
        if !secondaryActions.isEmpty {
            HStack(spacing: 12) {
                ForEach(Array(secondaryActions.enumerated()), id: \.offset) { _, action in
                    ForgeButton(
                        title: action.title,
                        style: inverted ? .inverse : .secondary,
                        isLoading: loadingSecondaryTitle?.caseInsensitiveCompare(action.title) == .orderedSame,
                        accessibilityIdentifier: secondaryAccessibilityIdentifiers[action.title],
                        action: action.action
                    )
                }
            }
        }
    }
}

private struct TitlePulseModifier: ViewModifier {
    let value: Double?

    func body(content: Content) -> some View {
        if let value {
            content.forgeMetricPulse(value: value)
        } else {
            content
        }
    }
}

#Preview("Active Workout") {
    ForgeHeroCard(
        eyebrow: "Push Day",
        title: "Upper Body Strength",
        durationMinutes: 45,
        focusLine: "Chest · Shoulders · Triceps",
        exerciseLine: "Bench Press, Overhead Press, Lateral Raise",
        primaryAction: ("Start Workout", {}),
        secondaryActions: [("Regenerate", {}), ("Preview", {})]
    )
}

#Preview("Protein") {
    ForgeHeroCard(
        eyebrow: "Protein",
        title: "98 / 145g",
        footerLine: "47g left",
        progress: 0.68,
        accent: ForgeColors.accentBlue,
        titleStyle: .metric
    )
}
