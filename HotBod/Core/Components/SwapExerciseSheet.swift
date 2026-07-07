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

                List {
                if let substitutionGroup {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(substitutionGroup.name)
                                .font(ForgeTypography.heading)
                            Text(substitutionGroup.primaryMuscles.map(\.displayName).joined(separator: ", "))
                                .font(ForgeTypography.caption)
                                .foregroundStyle(ForgeColors.muted)
                            if let description = substitutionGroup.description, !description.isEmpty {
                                Text(description)
                                    .font(ForgeTypography.body)
                                    .foregroundStyle(ForgeColors.muted)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Swap Group")
                    }
                }

                if substitutes.isEmpty {
                    Text("No substitutes available for your equipment and limitations.")
                        .foregroundStyle(ForgeColors.muted)
                } else {
                    Section {
                        ForEach(substitutes) { exercise in
                            Button {
                                onSelect(exercise)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.name).font(ForgeTypography.heading)
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
                            }
                            .buttonStyle(.plain)
                            .disabled(exercise.id == currentExerciseId)
                        }
                    } header: {
                        Text("Alternatives")
                    } footer: {
                        Text("Swaps stay within the same muscle group and movement pattern.")
                    }
                }
            }
            }
            .forgeScreenNavigationHidden()
        }
    }
}
