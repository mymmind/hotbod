import SwiftUI
import Pow

struct MetricCard: View {
    let label: String
    let value: String
    var detail: String? = nil
    var inverted: Bool = false
    var accent: Color? = nil
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
                .foregroundStyle(valueColor)
                .contentTransition(.numericText())
                .modifier(MetricValueAnimationModifier(value: value, enabled: animateValue))
            if let detail {
                Text(detail)
                    .font(ForgeTypography.body)
                    .foregroundStyle(inverted ? ForgeColors.surface.opacity(0.8) : ForgeColors.muted)
            }
        }
        .overlay(alignment: .leading) {
            if let accent, !inverted {
                Rectangle()
                    .fill(accent)
                    .frame(width: 3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
    }

    private var labelColor: Color {
        if let accent, !inverted { return accent }
        return inverted ? ForgeColors.surface.opacity(0.7) : ForgeColors.muted
    }

    private var valueColor: Color {
        inverted ? ForgeColors.surface : ForgeColors.foreground
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
