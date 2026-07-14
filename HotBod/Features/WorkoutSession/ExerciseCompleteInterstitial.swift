import SwiftUI

struct ExerciseCompleteInterstitial: View {
    let exerciseName: String
    let setsCompleted: Int
    let volumeKg: Double
    let bestSetDescription: String?
    let averageRPE: Double?
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: ForgeSpacing.s5) {
            Text("EXERCISE COMPLETE")
                .font(ForgeTypography.label)
                .tracking(ForgeTracking.eyebrowWide)
                .foregroundStyle(ForgeColors.accentGreen)

            Text(exerciseName)
                .font(ForgeTypography.display)
                .foregroundStyle(ForgeColors.textPrimary)
                .multilineTextAlignment(.center)

            ForgeCard {
                VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                    statRow(label: "Sets logged", value: "\(setsCompleted)")
                    statRow(label: "Volume", value: "\(Int(volumeKg))kg")
                    if let bestSetDescription {
                        statRow(label: "Best set", value: bestSetDescription)
                    }
                    if let averageRPE {
                        statRow(label: "Avg effort", value: String(format: "RPE %.1f", averageRPE))
                    }
                }
            }

            ForgeButton(
                title: "Next Exercise",
                style: .accent,
                accessibilityIdentifier: "session.exerciseComplete.continue",
                action: onContinue
            )
        }
        .padding(ForgeSpacing.s5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ForgeColors.background.opacity(0.98))
        .accessibilityIdentifier("session.exerciseComplete")
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(ForgeTypography.tabLabel)
                .foregroundStyle(ForgeColors.muted)
            Spacer()
            Text(value)
                .font(ForgeTypography.metric)
                .foregroundStyle(ForgeColors.textPrimary)
        }
    }
}

#Preview {
    ExerciseCompleteInterstitial(
        exerciseName: "Bench Press",
        setsCompleted: 3,
        volumeKg: 480,
        bestSetDescription: "80kg × 8",
        averageRPE: 8.5,
        onContinue: {}
    )
}
