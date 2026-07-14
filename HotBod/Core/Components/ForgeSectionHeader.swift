import SwiftUI

struct ForgeSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var accent: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(ForgeTypography.caption)
                .tracking(2)
                .foregroundStyle(accent ?? ForgeColors.muted)
            if let subtitle {
                Text(subtitle)
                    .font(ForgeTypography.heading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        if let subtitle {
            return "\(title). \(subtitle)"
        }
        return title
    }
}
