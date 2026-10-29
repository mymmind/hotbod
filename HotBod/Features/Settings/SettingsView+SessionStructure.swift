import SwiftUI

extension SettingsView {
    var sessionStructureSection: some View {
        SettingsComponents.section(title: "Session structure", subtitle: "Warm-up, cooldown, and cardio") {
            SettingsComponents.toggleRow(title: "Warm-up stretches", isOn: $draft.includeWarmupStretches)
            SettingsComponents.divider
            SettingsComponents.toggleRow(title: "Cooldown sets", isOn: $draft.includeCooldown)
            SettingsComponents.divider
            SettingsComponents.toggleRow(title: "Core finisher", isOn: $draft.includeCoreFinisher)
            SettingsComponents.divider
            SettingsComponents.toggleRow(title: "Ask for reps in reserve", isOn: $draft.promptForEffortFeedback)
            SettingsComponents.divider
            SettingsComponents.toggleRow(title: "Use older effort entries", isOn: $draft.trustHistoricEffortFeedback)
            SettingsComponents.divider
            SettingsComponents.toggleRow(title: "Include conditioning", isOn: $draft.includeConditioning)
            SettingsComponents.divider
            SettingsComponents.menuRow(
                title: "Cardio block",
                value: draft.cardioBlockPlacement.displayName
            ) {
                ForEach(CardioBlockPlacement.allCases, id: \.self) { placement in
                    Button(placement.displayName) { draft.cardioBlockPlacement = placement }
                }
            }
            Text(
                "Warm-up stretches are short mobility holds before the first lift. "
                    + "Warm-up sets, under Training, ramp the load on each exercise. "
                    + "Cooldown adds a light set after working sets. "
                    + "Cardio blocks bookend the session when equipment allows."
            )
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
        }
    }

    var equipmentLimitsSection: some View {
        SettingsComponents.section(title: "Equipment limits", subtitle: "Cap prescribed loads to what you own") {
            ForEach(SettingsDraftEditing.weightLimitedEquipment(in: draft), id: \.self) { equipment in
                equipmentLimitRow(for: equipment)
                if equipment != SettingsDraftEditing.weightLimitedEquipment(in: draft).last {
                    SettingsComponents.divider
                }
            }
            if SettingsDraftEditing.weightLimitedEquipment(in: draft).isEmpty {
                Text("Select dumbbells, barbells, or kettlebells in Equipment to set max weights.")
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.muted)
            }
        }
    }

    @ViewBuilder
    private func equipmentLimitRow(for equipment: Equipment) -> some View {
        let binding = Binding<String>(
            get: {
                if let value = draft.maxAvailableWeightKg[equipment] {
                    return String(format: "%.0f", value)
                }
                return ""
            },
            set: { text in
                SettingsDraftEditing.setEquipmentWeightLimit(
                    equipment: equipment,
                    text: text,
                    in: &draft
                )
            }
        )

        let maxLabel = equipment == .dumbbell
            ? "dumbbell (\(WeightDisplaySemantics.perHand.settingsWeightLabel))"
            : "\(equipment.displayName.lowercased()) (kg)"

        VStack(alignment: .leading, spacing: 8) {
            Text("Max \(maxLabel)")
                .font(ForgeTypography.body)
            TextField("No limit", text: binding)
                .keyboardType(.decimalPad)
                .padding(12)
                .overlay(Rectangle().stroke(ForgeColors.border, lineWidth: 1))
                .accessibilityLabel("Max \(equipment.displayName) weight in kilograms")
        }
    }
}
