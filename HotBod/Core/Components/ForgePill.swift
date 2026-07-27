import SwiftUI

struct ForgePill: View {
    let label: String
    /// Legacy flag from light-mode inverted pills. Ignored in dark-only.
    var inverted: Bool = false

    var body: some View {
        Text(label)
            .font(ForgeTypography.caption)
            .foregroundStyle(ForgeColors.foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ForgeColors.foreground.opacity(0.12))
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(ForgeColors.border, lineWidth: 1)
            }
            .accessibilityLabel(label)
    }
}
