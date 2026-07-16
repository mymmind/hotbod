// swiftlint:disable function_body_length function_parameter_count
import SwiftUI

extension WorkoutSessionView {
    func setTable(exercise: WorkoutExercise, meta: Exercise) -> some View {
        let activeSetIndex = exercise.completedSets.count
        let warmupsAtStart = exercise.plannedSets.prefix(while: \.isWarmup).count
        let loadMode = meta.resolvedLoadTrackingMode
        let hasExternalLoadInHistory = exercise.completedSets.contains { $0.weightKg != nil }
            || exercise.plannedSets.contains(where: { $0.targetWeightKg != nil })
        let optionalEnabled = optionalLoadEnabledByExerciseId[exercise.id] ?? hasExternalLoadInHistory

        let showWeightInput: Bool
        switch loadMode {
        case .none:
            showWeightInput = false
        case .optional:
            showWeightInput = optionalEnabled
        case .supported, .required:
            showWeightInput = true
        }

        return VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
            Text("SETS")
                .font(ForgeTypography.label)
                .tracking(ForgeTracking.eyebrowWide)
                .foregroundStyle(ForgeColors.accent)

            if let groupLabel = ExerciseGroupPlanner.contextLabel(
                for: session.exercises,
                exercise: exercise,
                exerciseMap: exerciseMap,
                groupingPreference: environment.userProfile?.preferredExerciseGrouping ?? .none
            ) {
                Text(groupLabel.uppercased())
                    .font(ForgeTypography.tabLabel)
                    .tracking(ForgeTracking.eyebrowWide)
                    .foregroundStyle(ForgeColors.accentGreen)
            }

            if loadMode == .optional {
                let enabledBinding = Binding<Bool>(
                    get: { optionalLoadEnabledByExerciseId[exercise.id] ?? hasExternalLoadInHistory },
                    set: { newValue in
                        optionalLoadEnabledByExerciseId[exercise.id] = newValue
                        // Clear any typed weights when toggling the mode.
                        weightTexts = [:]
                    }
                )

                SettingsComponents.toggleRow(title: "Add load", isOn: enabledBinding)
                    .padding(.horizontal, ForgeSpacing.s4)
            }

            VStack(spacing: 0) {
                setTableColumnHeader(exercise: exercise, meta: meta, showWeightInput: showWeightInput)

                Rectangle()
                    .fill(ForgeColors.border)
                    .frame(height: ForgeBorder.hairline)

                ForEach(Array(exercise.plannedSets.enumerated()), id: \.element.id) { index, planned in
                    let completed = exercise.completedSets.first { $0.setIndex == index }
                    let isActive = index == activeSetIndex && completed == nil
                    let isDone = completed != nil

                    VStack(spacing: 0) {
                        setRow(
                            exerciseId: exercise.id,
                            meta: meta,
                            index: index,
                            warmupsAtStart: warmupsAtStart,
                            planned: planned,
                            completed: completed,
                            isActive: isActive,
                            isDone: isDone,
                            showWeightInput: showWeightInput
                        )

                        if !planned.isWarmup && !planned.isCooldown && (isActive || isDone) {
                            rpePickerRow(
                                plannedSetId: planned.id,
                                planned: planned,
                                exerciseId: exercise.id,
                                setIndex: index,
                                completed: completed,
                                isActive: isActive
                            )
                        }
                    }

                    if index < exercise.plannedSets.count - 1 {
                        Rectangle()
                            .fill(ForgeColors.border)
                            .frame(height: ForgeBorder.hairline)
                    }
                }
            }
            .overlay(Rectangle().stroke(ForgeColors.border, lineWidth: ForgeBorder.hairline))
        }
    }

    func setTableColumnHeader(exercise: WorkoutExercise, meta: Exercise, showWeightInput: Bool) -> some View {
        HStack(spacing: ForgeSpacing.s3) {
            Text("#")
                .font(ForgeTypography.tabLabel)
                .tracking(ForgeTracking.tight)
                .foregroundStyle(ForgeColors.textSecondary)
                .frame(width: ForgeSetTableLayout.setNumberWidth, alignment: .leading)

            Text("TARGET")
                .font(ForgeTypography.tabLabel)
                .tracking(ForgeTracking.tight)
                .foregroundStyle(ForgeColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: ForgeSetTableLayout.fieldSpacing) {
                if showWeightInput || !usesRepMetric(for: meta) {
                    Text(weightLabel(for: meta, showWeightInput: showWeightInput))
                        .frame(width: ForgeSetTableLayout.weightFieldWidth)
                }
                if usesDurationMetric(for: meta) {
                    Text("SEC")
                        .frame(width: ForgeSetTableLayout.metricFieldWidth)
                }
                if usesDistanceMetric(for: meta) {
                    Text("M")
                        .frame(width: ForgeSetTableLayout.metricFieldWidth)
                }
                if usesRepMetric(for: meta) {
                    Text("REPS")
                        .frame(width: ForgeSetTableLayout.repsFieldWidth)
                }
            }
            .font(ForgeTypography.tabLabel)
            .tracking(ForgeTracking.tight)
            .foregroundStyle(ForgeColors.textSecondary)
        }
        .padding(.horizontal, ForgeSpacing.s4)
        .padding(.vertical, ForgeSpacing.s2)
        .background(ForgeColors.surface.opacity(0.35))
    }

    func setRow(
        exerciseId: UUID,
        meta: Exercise,
        index: Int,
        warmupsAtStart: Int,
        planned: PlannedSet,
        completed: CompletedSet?,
        isActive: Bool,
        isDone: Bool,
        showWeightInput: Bool
    ) -> some View {
        HStack(spacing: ForgeSpacing.s3) {
            Text(setLabel(planned: planned, index: index, warmupsAtStart: warmupsAtStart))
                .font(ForgeTypography.metric)
                .foregroundStyle(
                    planned.isWarmup
                        ? (isDone ? ForgeColors.textSecondary : ForgeColors.textPrimary)
                        : (isDone ? ForgeColors.accentGreen : (isActive ? ForgeColors.textPrimary : ForgeColors.textSecondary))
                )
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(targetText(planned, meta: meta, showWeightInput: showWeightInput))
                    .font(ForgeTypography.body)
                    .foregroundStyle(isDone ? ForgeColors.textSecondary : ForgeColors.textPrimary)
                if isActive {
                    Text(activeSetSubtitle(for: planned))
                        .font(ForgeTypography.tabLabel)
                        .foregroundStyle(activeSetSubtitleColor(for: planned))
                } else if planned.isMaxEffort {
                    Text("Max effort")
                        .font(ForgeTypography.tabLabel)
                        .foregroundStyle(ForgeColors.accentAmber)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: ForgeSetTableLayout.fieldSpacing) {
                if showWeightInput {
                    ForgeSetMetricField(
                        label: weightLabel(for: meta, showWeightInput: true),
                        text: bindingWeight(
                            exerciseId: exerciseId,
                            planned: planned,
                            setIndex: index,
                            completed: completed,
                            showWeightInput: showWeightInput
                        ),
                        width: ForgeSetTableLayout.weightFieldWidth,
                        isActive: isActive,
                        selectAllOnFocus: true
                    )
                } else if !usesRepMetric(for: meta) {
                    Text("BW")
                        .font(ForgeTypography.metric)
                        .foregroundStyle(isActive || isDone ? ForgeColors.textPrimary : ForgeColors.textSecondary)
                        .frame(width: ForgeSetTableLayout.weightFieldWidth, alignment: .center)
                } else {
                    Text("BW")
                        .font(ForgeTypography.metric)
                        .foregroundStyle(isActive || isDone ? ForgeColors.textPrimary : ForgeColors.textSecondary)
                        .frame(width: ForgeSetTableLayout.weightFieldWidth, alignment: .center)
                }

                if usesDurationMetric(for: meta) {
                    ForgeSetMetricField(
                        label: "Seconds",
                        text: bindingDuration(
                            exerciseId: exerciseId,
                            planned: planned,
                            setIndex: index,
                            completed: completed
                        ),
                        width: ForgeSetTableLayout.metricFieldWidth,
                        isActive: isActive,
                        keyboardType: .numberPad
                    )
                }

                if usesDistanceMetric(for: meta) {
                    ForgeSetMetricField(
                        label: "Meters",
                        text: bindingDistance(
                            exerciseId: exerciseId,
                            planned: planned,
                            setIndex: index,
                            completed: completed
                        ),
                        width: ForgeSetTableLayout.metricFieldWidth,
                        isActive: isActive,
                        keyboardType: .decimalPad,
                        selectAllOnFocus: true
                    )
                }

                if usesRepMetric(for: meta) {
                    ForgeSetMetricField(
                        label: "Reps",
                        text: bindingReps(
                            exerciseId: exerciseId,
                            planned: planned,
                            setIndex: index,
                            completed: completed
                        ),
                        width: ForgeSetTableLayout.repsFieldWidth,
                        isActive: isActive,
                        keyboardType: .numberPad
                    )
                }

                if isDone {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ForgeColors.accentGreen)
                        .frame(width: 14)
                }
            }
        }
        .padding(.horizontal, ForgeSpacing.s4)
        .padding(.vertical, ForgeSpacing.s3)
        .background(isActive ? ForgeColors.accent.opacity(0.06) : Color.clear)
        .forgeSetCompleteFlash(isActive: flashSetId == planned.id)
        .forgePRFlash(isActive: prSetId == planned.id)
    }

    func setLabel(planned: PlannedSet, index: Int, warmupsAtStart: Int) -> String {
        if planned.isWarmup { return "W" }
        if planned.isCooldown { return "C" }
        return "\(index - warmupsAtStart + 1)"
    }

    func activeSetSubtitle(for planned: PlannedSet) -> String {
        if planned.isMaxEffort { return "Max effort · AMRAP" }
        if planned.isWarmup { return "Warm-up set" }
        if planned.isCooldown { return "Cooldown set" }
        return "Current set"
    }

    func activeSetSubtitleColor(for planned: PlannedSet) -> Color {
        if planned.isMaxEffort { return ForgeColors.accentAmber }
        if planned.isCooldown { return ForgeColors.accentGreen }
        return ForgeColors.accent
    }

    func rpePickerRow(
        plannedSetId: UUID,
        planned: PlannedSet,
        exerciseId: UUID,
        setIndex: Int,
        completed: CompletedSet?,
        isActive: Bool
    ) -> some View {
        let selection = isActive ? pendingRpeBySetId[plannedSetId] : completed?.rpe

        return ForgeRPEPicker(selection: selection, rpeTarget: planned.rpeTarget) { value in
            if isActive {
                pendingRpeBySetId[plannedSetId] = value
            } else {
                updateCompletedSet(exerciseId: exerciseId, setIndex: setIndex, rpe: value)
            }
        }
        .padding(.horizontal, ForgeSpacing.s4)
        .padding(.vertical, ForgeSpacing.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColors.surface.opacity(isActive ? 0.2 : 0.1))
    }

    func bindingWeight(
        exerciseId: UUID,
        planned: PlannedSet,
        setIndex: Int,
        completed: CompletedSet?,
        showWeightInput: Bool
    ) -> Binding<String> {
        Binding(
            get: {
                weightTexts[planned.id]
                    ?? completed?.weightKg.map(WorkoutSessionMetricDrafts.formatWeightKg)
                    ?? planned.targetWeightKg.map(WorkoutSessionMetricDrafts.formatWeightKg)
                    ?? ""
            },
            set: { newValue in
                weightTexts[planned.id] = newValue
                guard completed != nil else { return }
                let weight = showWeightInput ? Double(newValue) : nil
                updateCompletedSet(exerciseId: exerciseId, setIndex: setIndex, weightKg: weight)
            }
        )
    }

    func bindingDuration(
        exerciseId: UUID,
        planned: PlannedSet,
        setIndex: Int,
        completed: CompletedSet?
    ) -> Binding<String> {
        Binding(
            get: {
                durationTexts[planned.id]
                    ?? completed?.durationSeconds.map(String.init)
                    ?? planned.targetDurationSeconds.map(String.init)
                    ?? ""
            },
            set: { newValue in
                durationTexts[planned.id] = newValue
                guard completed != nil, let seconds = Int(newValue) else { return }
                updateCompletedSet(exerciseId: exerciseId, setIndex: setIndex, durationSeconds: seconds)
            }
        )
    }

    func bindingDistance(
        exerciseId: UUID,
        planned: PlannedSet,
        setIndex: Int,
        completed: CompletedSet?
    ) -> Binding<String> {
        Binding(
            get: {
                distanceTexts[planned.id]
                    ?? completed?.distanceMeters.map { String(format: "%.0f", $0) }
                    ?? planned.targetDistanceMeters.map { String(format: "%.0f", $0) }
                    ?? ""
            },
            set: { newValue in
                distanceTexts[planned.id] = newValue
                guard completed != nil, let meters = Double(newValue) else { return }
                updateCompletedSet(exerciseId: exerciseId, setIndex: setIndex, distanceMeters: meters)
            }
        )
    }

    func bindingReps(
        exerciseId: UUID,
        planned: PlannedSet,
        setIndex: Int,
        completed: CompletedSet?
    ) -> Binding<String> {
        Binding(
            get: { repsTexts[planned.id] ?? (completed.map { String($0.reps) } ?? String(planned.targetRepsMin)) },
            set: { newValue in
                repsTexts[planned.id] = newValue
                guard completed != nil, let reps = Int(newValue) else { return }
                updateCompletedSet(exerciseId: exerciseId, setIndex: setIndex, reps: reps)
            }
        )
    }

    func updateCompletedSet(
        exerciseId: UUID,
        setIndex: Int,
        weightKg: Double? = nil,
        reps: Int? = nil,
        rpe: Double? = nil,
        rir: Int? = nil,
        durationSeconds: Int? = nil,
        distanceMeters: Double? = nil
    ) {
        guard let exerciseIdx = session.exercises.firstIndex(where: { $0.id == exerciseId }),
              let completedIdx = session.exercises[exerciseIdx].completedSets.firstIndex(where: { $0.setIndex == setIndex })
        else { return }

        if let weightKg {
            session.exercises[exerciseIdx].completedSets[completedIdx].weightKg = weightKg
        }
        if let reps {
            session.exercises[exerciseIdx].completedSets[completedIdx].reps = reps
        }
        if let rpe {
            session.exercises[exerciseIdx].completedSets[completedIdx].rpe = rpe
        }
        if let rir {
            session.exercises[exerciseIdx].completedSets[completedIdx].rir = rir
        }
        if let durationSeconds {
            session.exercises[exerciseIdx].completedSets[completedIdx].durationSeconds = durationSeconds
        }
        if let distanceMeters {
            session.exercises[exerciseIdx].completedSets[completedIdx].distanceMeters = distanceMeters
        }
        environment.scheduleWorkoutSessionSave(session)
    }

    func dismissKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
#endif
    }
}
