import SwiftUI

extension SettingsView {
    var trainingSection: some View {
        SettingsComponents.section(title: "Training", subtitle: "Program preferences") {
            SettingsComponents.menuRow(title: "Goal", value: draft.goal.displayName) {
                ForEach(TrainingGoal.allCases) { goal in
                    Button(goal.displayName) { draft.goal = goal }
                }
            }
            SettingsComponents.divider
            SettingsComponents.menuRow(title: "Experience", value: draft.experienceLevel.displayName) {
                ForEach(ExperienceLevel.allCases) { level in
                    Button(level.displayName) { draft.experienceLevel = level }
                }
            }
            SettingsComponents.divider
            SettingsComponents.menuRow(title: "Split", value: draft.preferredSplit.displayName) {
                ForEach(TrainingSplit.selectableSplits) { split in
                    Button(split.displayName) { draft.preferredSplit = split }
                }
            }
            SettingsComponents.divider
            SettingsComponents.toggleRow(title: "Warm-up sets", isOn: $draft.includeWarmupSets)
            SettingsComponents.divider
            SettingsComponents.menuRow(
                title: "Exercise grouping",
                value: draft.preferredExerciseGrouping.displayName
            ) {
                ForEach(ExerciseGroupingPreference.allCases, id: \.self) { preference in
                    Button(preference.displayName) { draft.preferredExerciseGrouping = preference }
                }
            }
            SettingsComponents.divider
            SettingsComponents.menuRow(
                title: "Exercise variability",
                value: draft.preferredExerciseVariability.displayName
            ) {
                ForEach(ExerciseVariabilityLevel.allCases, id: \.self) { level in
                    Button(level.displayName) { draft.preferredExerciseVariability = level }
                }
            }
            SettingsComponents.divider
            SettingsComponents.menuRow(title: "Location", value: draft.trainingLocation.displayName) {
                ForEach(TrainingLocation.allCases) { location in
                    Button(location.displayName) { draft.trainingLocation = location }
                }
            }
            SettingsComponents.divider
            Button { showEquipmentPicker = true } label: {
                SettingsComponents.valueRow(
                    label: "Equipment",
                    value: "\(draft.availableEquipment.count) selected",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.equipment.row")
            .accessibilityAddTraits(.isButton)
        }
    }

    var musclePreferencesSection: some View {
        SettingsComponents.section(title: "Muscle focus", subtitle: "Bias generation toward or away from muscles") {
            Button {
                withAnimation(ForgeMotion.quick) { showMusclePreferences.toggle() }
            } label: {
                SettingsComponents.valueRow(
                    label: "Preferences",
                    value: SettingsDraftEditing.musclePreferencesSummary(for: draft),
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            if showMusclePreferences {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Preferred")
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.muted)
                    muscleChipGrid(
                        selected: Binding(
                            get: { Set(draft.preferredMuscleGroups ?? []) },
                            set: { draft.preferredMuscleGroups = Array($0) }
                        ),
                        excluded: Set(draft.avoidedMuscleGroups ?? [])
                    ) { muscle in
                        SettingsDraftEditing.togglePreferredMuscle(muscle, in: &draft)
                    }

                    Text("Avoided")
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.muted)
                    muscleChipGrid(
                        selected: Binding(
                            get: { Set(draft.avoidedMuscleGroups ?? []) },
                            set: { draft.avoidedMuscleGroups = Array($0) }
                        ),
                        excluded: Set(draft.preferredMuscleGroups ?? [])
                    ) { muscle in
                        SettingsDraftEditing.toggleAvoidedMuscle(muscle, in: &draft)
                    }

                    Text("Preferred muscles get priority when recovery is similar. Avoided muscles are skipped unless the session cannot be built otherwise.")
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.muted)
                }
                .transition(ForgeMotion.disclosureExpand)
            }
        }
    }

    var scheduleSection: some View {
        SettingsComponents.section(title: "Schedule", subtitle: "Frequency and length") {
            Text("\(draft.preferredTrainingDays.count) days per week")
                .font(ForgeTypography.body)

            Text("Session length")
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
                .padding(.top, 4)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                ForEach(sessionLengths, id: \.self) { minutes in
                    SelectableChip(
                        title: "\(minutes)m",
                        isSelected: draft.preferredSessionLengthMinutes == minutes
                    ) {
                        draft.preferredSessionLengthMinutes = minutes
                    }
                }
            }

            Text("Preferred days")
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
                .padding(.top, 4)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], spacing: 8) {
                ForEach(Weekday.allCases) { day in
                    SelectableChip(
                        title: day.shortName,
                        isSelected: draft.preferredTrainingDays.contains(day)
                    ) {
                        SettingsDraftEditing.toggleTrainingDay(day, in: &draft)
                    }
                }
            }
        }
    }

    func muscleChipGrid(
        selected: Binding<Set<MuscleGroup>>,
        excluded: Set<MuscleGroup>,
        onTap: @escaping (MuscleGroup) -> Void
    ) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
            ForEach(MuscleGroup.preferenceSelectable) { muscle in
                SelectableChip(
                    title: muscle.displayName,
                    isSelected: selected.wrappedValue.contains(muscle),
                    isDisabled: excluded.contains(muscle)
                ) {
                    onTap(muscle)
                }
            }
        }
    }

    var equipmentPicker: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Equipment.allCases) { equipment in
                        MultiSelectRow(
                            title: equipment.displayName,
                            isSelected: draft.availableEquipment.contains(equipment)
                        ) {
                            SettingsDraftEditing.toggleEquipment(equipment, in: &draft)
                        }
                    }
                }
                .padding(16)
            }
            .background(ForgeColors.background)
            .navigationTitle("Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showEquipmentPicker = false }
                        .foregroundStyle(ForgeColors.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
