import SwiftUI

struct MetricCard: View {
    let label: String
    let value: String
    var detail: String?
    /// Legacy flag from light-mode inverted cards. Ignored in dark-only.
    var inverted: Bool = false
    var accent: Color?
    var animateValue: Bool = true

    var body: some View {
        ForgeCard(inverted: inverted) {
            Text(label.uppercased())
                .font(ForgeTypography.caption)
                .tracking(1.5)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
                .foregroundStyle(labelColor)
            Text(value)
                .font(ForgeTypography.heroMetric)
                .foregroundStyle(ForgeColors.foreground)
                .contentTransition(.numericText())
                .modifier(MetricValueAnimationModifier(value: value, enabled: animateValue))
            if let detail {
                Text(detail)
                    .font(ForgeTypography.body)
                    .foregroundStyle(ForgeColors.muted)
            }
        }
        .overlay(alignment: .leading) {
            if let accent {
                Rectangle()
                    .fill(accent)
                    .frame(width: 3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
    }

    private var labelColor: Color {
        accent ?? ForgeColors.muted
    }
}

private struct MetricValueAnimationModifier: ViewModifier {
    let value: String
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .forgeMetricPulse(value: value)
        } else {
            content
        }
    }
}
