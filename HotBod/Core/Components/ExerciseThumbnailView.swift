import SwiftUI

struct ExerciseThumbnailView: View {
    let exerciseId: String
    let primaryMuscle: String?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle.forge(ForgeRadius.md)
                .fill(
                    LinearGradient(
                        colors: [
                            ForgeColors.foreground.opacity(0.06),
                            ForgeColors.accent.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundStyle(ForgeColors.accent)
                        .padding(10)
                        .background(Circle().fill(ForgeColors.surface.opacity(0.9)))
                }

            if let primaryMuscle {
                Text(primaryMuscle.prefix(3).uppercased())
                    .font(ForgeTypography.tabLabel.weight(.bold))
                    .foregroundStyle(ForgeColors.textOnInverse)
                    .padding(.horizontal, ForgeSpacing.s1 + 1)
                    .padding(.vertical, ForgeSpacing.s1 - 1)
                    .background(ForgeColors.surfaceInverse.opacity(0.85))
                    .clipShape(RoundedRectangle.forge(ForgeRadius.xs))
                    .padding(ForgeSpacing.s1)
            }
        }
        .accessibilityLabel(primaryMuscle ?? exerciseId)
    }
}
