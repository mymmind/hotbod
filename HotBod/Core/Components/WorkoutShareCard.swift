import SwiftUI

struct WorkoutShareCard: View {
    let title: String
    let volumeKg: Int
    let sets: Int
    let durationMinutes: Int
    let workoutStreak: Int
    var muscleSummary: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s4) {
            Text("HOTBOD")
                .font(ForgeTypography.caption)
                .tracking(ForgeTracking.eyebrowWide)
                .foregroundStyle(ForgeColors.accent)

            Text(title.uppercased())
                .font(ForgeTypography.displayAthletic)
                .foregroundStyle(ForgeColors.textOnInverse)
                .lineLimit(2)

            HStack(spacing: ForgeSpacing.s4) {
                shareMetric(label: "Volume", value: "\(volumeKg)kg")
                shareMetric(label: "Sets", value: "\(sets)")
                shareMetric(label: "Time", value: "\(durationMinutes)m")
            }

            if workoutStreak > 0 {
                Text("\(workoutStreak)-day training streak")
                    .font(ForgeTypography.label)
                    .foregroundStyle(ForgeColors.accentGreen)
            }

            if let muscleSummary, !muscleSummary.isEmpty {
                Text(muscleSummary)
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.muted)
                    .lineLimit(2)
            }
        }
        .padding(ForgeSpacing.s5)
        .frame(maxWidth: 360, alignment: .leading)
        .background(ForgeColors.surfaceInverse)
    }

    private func shareMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
            Text(value)
                .font(ForgeTypography.monoMetric)
                .foregroundStyle(ForgeColors.textOnInverse)
        }
    }
}

enum WorkoutShareRenderer {
    @MainActor
    static func image(for card: WorkoutShareCard) -> UIImage? {
#if canImport(UIKit)
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
#else
        return nil
#endif
    }
}
