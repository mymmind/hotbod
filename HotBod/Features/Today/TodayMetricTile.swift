import SwiftUI

struct TodayMetricTile: View {
    let label: String
    let value: String
    let progress: Double
    var accent: Color = ForgeColors.accent
    var subtitle: String? = nil
    var iconName: String = "chart.bar.fill"
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) { tileContent }
                    .buttonStyle(TodayMetricPressStyle())
                    .accessibilityLabel("\(label), \(value)")
            } else {
                tileContent
            }
        }
    }

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s3 - 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased())
                    .font(ForgeTypography.label)
                    .tracking(ForgeTracking.eyebrow)
                    .foregroundStyle(accent)
                Spacer(minLength: 0)
                Image(systemName: iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent.opacity(0.85))
            }

            Text(value)
                .font(ForgeTypography.metric)
                .foregroundStyle(ForgeColors.textPrimary)
                .contentTransition(.numericText())
                .forgeMetricPulse(value: value)

            ForgeProgressBar(progress: progress, fill: accent)

            if let subtitle {
                Text(subtitle)
                    .font(ForgeTypography.label)
                    .foregroundStyle(ForgeColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(ForgeSpacing.s4)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background {
            RoundedRectangle.forge(ForgeRadius.soft)
                .fill(
                    LinearGradient(
                        colors: [ForgeColors.surface, accent.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .forgeElevation(.metricTile(accent))
        }
        .overlay {
            RoundedRectangle.forge(ForgeRadius.soft)
                .stroke(ForgeColors.border, lineWidth: ForgeBorder.hairline)
        }
    }
}

private struct TodayMetricPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(ForgeMotion.quick, value: configuration.isPressed)
    }
}

#Preview {
    HStack(spacing: ForgeSpacing.s3) {
        TodayMetricTile(
            label: "Overall",
            value: "72%",
            progress: 0.72,
            accent: ForgeColors.accentGreen,
            subtitle: "28% to full",
            iconName: "bolt.heart.fill"
        )
        TodayMetricTile(
            label: "Protein",
            value: "98g",
            progress: 0.68,
            accent: ForgeColors.accentBlue,
            subtitle: "47g left",
            iconName: "fork.knife"
        )
    }
    .padding()
}
