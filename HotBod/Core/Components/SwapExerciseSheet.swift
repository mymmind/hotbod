import SwiftUI

struct SwapExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let currentExerciseId: String
    let substitutionGroup: ExerciseSubstitutionGroup?
    let substitutes: [Exercise]
    let onSelect: (Exercise) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ForgeScreenHeader(
                    title: "Swap Exercise",
                    style: .compact,
                    presentation: .sheet,
                    eyebrow: "Session",
                    subtitle: "Same muscles, different movement.",
                    trailing: {
                        Button("Cancel") { dismiss() }
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.accent)
                    }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: ForgeSpacing.s4) {
                        if let substitutionGroup {
                            groupCard(substitutionGroup)
                        }

                        if substitutes.isEmpty {
                            Text("No substitutes available for your equipment and limitations.")
                                .font(ForgeTypography.body)
                                .foregroundStyle(ForgeColors.muted)
                                .padding(.horizontal, ForgeSpacing.s4)
                        } else {
                            alternativesSection
                        }
                    }
                    .padding(.vertical, ForgeSpacing.s4)
                }
            }
            .background(ForgeColors.background)
            .forgeScreenNavigationHidden()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("swap.sheet")
        .presentationDetents([.medium, .large])
    }

    private func groupCard(_ group: ExerciseSubstitutionGroup) -> some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("SWAP GROUP")
                    .font(ForgeTypography.caption)
                    .tracking(ForgeTracking.eyebrowWide)
                    .foregroundStyle(ForgeColors.muted)
                Text(group.name)
                    .font(ForgeTypography.heading)
                Text(group.primaryMuscles.map(\.displayName).joined(separator: ", "))
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.muted)
                if let description = group.description, !description.isEmpty {
                    Text(description)
                        .font(ForgeTypography.body)
                        .foregroundStyle(ForgeColors.muted)
                }
            }
        }
        .padding(.horizontal, ForgeSpacing.s4)
    }

    private var alternativesSection: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
            Text("ALTERNATIVES")
                .font(ForgeTypography.caption)
                .tracking(ForgeTracking.eyebrowWide)
                .foregroundStyle(ForgeColors.muted)
                .padding(.horizontal, ForgeSpacing.s4)

            ForgeCard {
                VStack(spacing: 0) {
                    ForEach(substitutes) { exercise in
                        Button {
                            onSelect(exercise)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name)
                                        .font(ForgeTypography.heading)
                                        .foregroundStyle(ForgeColors.foreground)
                                    Text(exercise.equipment.map(\.displayName).joined(separator: " · "))
                                        .font(ForgeTypography.caption)
                                        .foregroundStyle(ForgeColors.muted)
                                }
                                Spacer()
                                if exercise.id == currentExerciseId {
                                    Text("Current")
                                        .font(ForgeTypography.caption)
                                        .foregroundStyle(ForgeColors.muted)
                                }
                            }
                            .padding(.horizontal, ForgeSpacing.s4)
                            .padding(.vertical, ForgeSpacing.s3)
                        }
                        .buttonStyle(.plain)
                        .disabled(exercise.id == currentExerciseId)
                        .accessibilityIdentifier("swap.substitute.\(exercise.id)")

                        if exercise.id != substitutes.last?.id {
                            Rectangle()
                                .fill(ForgeColors.border)
                                .frame(height: ForgeBorder.hairline)
                        }
                    }
                }
            }
            .padding(.horizontal, ForgeSpacing.s4)

            Text("Swaps stay within the same muscle group and movement pattern.")
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
                .padding(.horizontal, ForgeSpacing.s4)
        }
    }
}
