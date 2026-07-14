import SwiftUI

struct ForgePill: View {
    let label: String
    var inverted: Bool = false

    var body: some View {
        Text(label)
            .font(ForgeTypography.caption)
            .foregroundStyle(inverted ? ForgeColors.surface : ForgeColors.foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background((inverted ? ForgeColors.surface : ForgeColors.foreground).opacity(0.12))
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(inverted ? ForgeColors.surface.opacity(0.25) : ForgeColors.border, lineWidth: 1)
            }
            .accessibilityLabel(label)
    }
}
