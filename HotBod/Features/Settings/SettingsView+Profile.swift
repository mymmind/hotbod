import SwiftUI

extension SettingsView {
    var bodySection: some View {
        SettingsComponents.section(title: "Body", subtitle: "Stats for programming") {
            ForgeTextField(label: "Weight (kg)", text: $weightText, keyboardType: .decimalPad)
            ForgeTextField(label: "Height (cm)", text: $heightText, keyboardType: .numberPad)
            ForgeTextField(label: "Age", text: $ageText, keyboardType: .numberPad)
        }
    }

    var proteinSection: some View {
        SettingsComponents.section(title: "Protein", subtitle: "Daily target") {
            ForgeTextField(label: "Goal (g)", text: $proteinText, keyboardType: .numberPad)

            SettingsComponents.actionRow(title: "Recalculate from weight") {
                let weight = Double(weightText) ?? draft.weightKg ?? 80
                let suggested = ProteinGoalCalculator.suggestedGoal(bodyWeightKg: weight, goal: draft.goal)
                proteinText = String(Int(suggested))
                draft.proteinGoalGrams = suggested
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(ProteinGoalCalculator.rangeOptions(bodyWeightKg: Double(weightText) ?? 80), id: \.label) { option in
                    SelectableChip(
                        title: option.label,
                        isSelected: Int(draft.proteinGoalGrams) == Int(option.grams)
                    ) {
                        draft.proteinGoalGrams = option.grams
                        proteinText = String(Int(option.grams))
                    }
                }
            }
        }
    }

    var limitationsSection: some View {
        SettingsComponents.section(title: "Limitations", subtitle: "Injuries and restrictions") {
            Button {
                withAnimation(ForgeMotion.quick) { showLimitations.toggle() }
            } label: {
                SettingsComponents.valueRow(
                    label: "Restrictions",
                    value: SettingsDraftEditing.limitationsSummary(for: draft),
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            if showLimitations {
                VStack(spacing: 8) {
                    ForEach(BodyLimitation.allCases) { limitation in
                        MultiSelectRow(
                            title: limitation.displayName,
                            isSelected: draft.limitations.contains(limitation)
                        ) {
                            SettingsDraftEditing.toggleLimitation(limitation, in: &draft)
                        }
                    }
                    ForgeTextField(label: "Notes (optional)", text: $limitationNotes)
                }
                .transition(ForgeMotion.disclosureExpand)
            }
        }
    }

    var appSection: some View {
        SettingsComponents.section(title: "App", subtitle: "About HotBod") {
            SettingsComponents.valueRow(
                label: "Plan",
                value: SubscriptionConfig.unrestrictedAccess
                    ? "Full access (dev)"
                    : (environment.isPro ? "Pro" : "Free (\(environment.remainingFreeRegenerations) regen left)")
            )
            if !SubscriptionConfig.unrestrictedAccess, !environment.isPro {
                SettingsComponents.divider
                SettingsComponents.actionRow(title: "Upgrade to Pro") {
                    environment.presentPaywall(for: .unlimitedGeneration)
                }
            }
            SettingsComponents.divider
            SettingsComponents.toggleRow(
                title: "Haptic feedback",
                isOn: Binding(
                    get: { environment.feedbackService.hapticsEnabled },
                    set: { environment.feedbackService.hapticsEnabled = $0 }
                )
            )
            SettingsComponents.divider
            SettingsComponents.toggleRow(
                title: "Sound effects",
                isOn: Binding(
                    get: { environment.feedbackService.soundsEnabled },
                    set: { environment.feedbackService.soundsEnabled = $0 }
                )
            )
            SettingsComponents.divider
            SettingsComponents.valueRow(label: "Version", value: "1.0.0")
            SettingsComponents.divider
            SettingsComponents.valueRow(label: "Name", value: AppConfig.appName)
            if !environment.isSupabaseConfigured {
                SettingsComponents.divider
                deleteDataActionRow(title: "Delete All Data", identifier: "settings.deleteAllData")
                if let deleteError {
                    Text(deleteError)
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.destructive)
                }
            }
            SettingsComponents.divider
            SettingsComponents.actionRow(title: "Reset Onboarding", destructive: true) {
                Task {
                    try? await environment.resetOnboarding()
                    dismissSettings()
                    router.showOnboarding()
                }
            }
        }
    }

    func loadDraft() {
        guard !didLoad, let profile = environment.userProfile else { return }
        didLoad = true
        draft = profile
        SettingsDraftEditing.reconcileSchedule(&draft)
        weightText = SettingsDraftEditing.formatted(profile.weightKg)
        heightText = SettingsDraftEditing.formatted(profile.heightCm)
        ageText = profile.age.map(String.init) ?? ""
        proteinText = String(Int(profile.proteinGoalGrams))
        limitationNotes = profile.limitationNotes ?? ""
    }

    func finish() async {
        saveError = nil
        guard environment.userProfile != nil else {
            dismissSettings()
            return
        }

        SettingsDraftEditing.applyTextFields(
            draft: &draft,
            weightText: weightText,
            heightText: heightText,
            ageText: ageText,
            proteinText: proteinText,
            limitationNotes: limitationNotes
        )
        SettingsDraftEditing.reconcileSchedule(&draft)
        guard SettingsDraftEditing.hasValidSchedule(draft) else {
            saveError = "Select at least two training days."
            return
        }
        guard let original = environment.userProfile else {
            dismissSettings()
            return
        }

        guard draft != original else {
            dismissSettings()
            return
        }

        isSaving = true
        defer { isSaving = false }

        let refreshWorkout = SettingsDraftEditing.shouldRefreshWorkout(draft: draft, comparedTo: original)
        let saved = await environment.updateUserProfile(draft, refreshWorkout: refreshWorkout)
        if saved {
            dismissSettings()
        } else {
            saveError = SettingsErrorMessages.save(syncMessage: environment.syncMessage)
        }
    }

    func dismissSettings() {
        switch presentation {
        case .sheet:
            dismiss()
        case .routerOverlay:
            router.dismissRoute()
        }
    }

}
