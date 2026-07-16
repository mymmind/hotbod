import SwiftUI

extension SettingsView {
    var sessionStructureSection: some View {
        SettingsComponents.section(title: "Session structure", subtitle: "Warm-up, cooldown, and cardio") {
            SettingsComponents.toggleRow(title: "Cooldown sets", isOn: $draft.includeCooldown)
            SettingsComponents.divider
            SettingsComponents.toggleRow(title: "Core finisher", isOn: $draft.includeCoreFinisher)
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
            Text("Cooldown adds a light mobility set after working sets on each exercise. Cardio blocks bookend the session when equipment allows.")
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
