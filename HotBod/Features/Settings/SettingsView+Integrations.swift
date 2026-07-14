import SwiftUI

extension SettingsView {
    var integrationsSection: some View {
        SettingsComponents.section(title: L10n.Settings.integrationsTitle, subtitle: L10n.Settings.integrationsSubtitle) {
            SettingsComponents.toggleRow(
                title: L10n.Settings.healthExportTitle,
                isOn: Binding(
                    get: { draft.exportWorkoutsToHealthKit },
                    set: { newValue in
                        draft.exportWorkoutsToHealthKit = newValue
                        if newValue {
                            Task { await environment.requestHealthKitWorkoutExportAuthorization() }
                        }
                    }
                )
            )
            Text(L10n.Settings.healthExportHint)
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)

            SettingsComponents.divider

            SettingsComponents.valueRow(
                label: L10n.Settings.stravaTitle,
                value: L10n.Settings.stravaComingSoon
            )
            .accessibilityLabel("\(L10n.Settings.stravaTitle). \(L10n.Settings.stravaComingSoon)")
        }
    }
}
