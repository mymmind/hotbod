import SwiftUI

struct WorkoutSessionView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State var session: WorkoutSession
    @State private var currentExerciseIndex: Int
    @State private var weightTexts: [UUID: String] = [:]
    @State private var repsTexts: [UUID: String] = [:]
    // For `loadTrackingMode == .optional` exercises: user can opt into external load input.
    @State private var optionalLoadEnabledByExerciseId: [UUID: Bool] = [:]
    @State private var restSecondsRemaining = 0
    @State private var isResting = false
    @State private var showCompletion = false
    @State private var exerciseMap: [String: Exercise] = [:]
    @State private var showSwapSheet = false
    @State private var progressionNotes: [String] = []
    @State private var allExercises: [Exercise] = []
    @State private var substitutionGroups: [ExerciseSubstitutionGroup] = []
    @State private var swapResolver: ExerciseSwapResolver?
    @State private var showPreview = false
    @State private var showExplanation = false
    @State private var showEndConfirmation = false
    @State private var showCancelConfirmation = false

    init(session: WorkoutSession) {
        _session = State(initialValue: session)
        _currentExerciseIndex = State(initialValue: WorkoutSessionCalculator.currentExerciseIndex(for: session))
    }

    private var currentExercise: WorkoutExercise? {
        guard currentExerciseIndex < session.exercises.count else { return nil }
        return session.exercises[currentExerciseIndex]
    }

    private var completedSetsCount: Int {
        session.exercises.reduce(0) { $0 + $1.completedSets.count }
    }

    private var totalPlannedSets: Int {
        WorkoutSessionCalculator.totalPlannedSets(exercises: session.exercises)
    }

    private var bodyWeightKg: Double {
        environment.userProfile?.weightKg ?? 80
    }

    var body: some View {
        Group {
            if showCompletion {
                WorkoutCompletionView(session: session, progressionNotes: progressionNotes) {
                    Task {
                        await environment.refreshWorkoutAfterSession(session)
                        router.dismissToMain()
                    }
                }
                .transition(ForgeMotion.rise)
                .id("completion")
            } else if let exercise = currentExercise, let meta = exerciseMap[exercise.exerciseId] {
                sessionContent(exercise: exercise, meta: meta)
                    .transition(ForgeMotion.appear)
                    .id("session")
            } else {
                ProgressView().task { await loadExercises() }
                    .id("loading")
            }
        }
        .animation(ForgeMotion.standard, value: showCompletion)
        .animation(ForgeMotion.exercise, value: currentExerciseIndex)
        .background(ForgeColors.background)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await environment.setActiveWorkoutSession(session)
        }
        .sheet(isPresented: $showPreview) {
            ActiveWorkoutPreviewView(
                session: session,
                currentExerciseIndex: currentExerciseIndex,
                exerciseMap: exerciseMap
            )
        }
        .sheet(isPresented: $showExplanation) {
            WorkoutExplanationSheet(
                title: session.title,
                rationale: environment.todayWorkout?.rationale ?? "",
                safetyNotes: environment.todayWorkout?.safetyNotes ?? []
            )
        }
        .confirmationDialog("End Workout?", isPresented: $showEndConfirmation, titleVisibility: .visible) {
            Button("End & Save Progress") { finishWorkout() }
            Button("Keep Training", role: .cancel) {}
        } message: {
            Text("Your logged sets will be saved and counted toward today's session.")
        }
        .confirmationDialog("Cancel Workout?", isPresented: $showCancelConfirmation, titleVisibility: .visible) {
            Button("Cancel Workout", role: .destructive) {
                Task {
                    await environment.cancelWorkoutSession(session)
                    router.dismissToMain()
                }
            }
            Button("Keep Training", role: .cancel) {}
        } message: {
            Text("This discards the session. Logged sets will not count toward today.")
        }
    }

    private func sessionContent(exercise: WorkoutExercise, meta: Exercise) -> some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 0).id("sessionTop")

                        WorkoutSessionHeaderView(
                            onExit: {
                                Task {
                                    await environment.pauseWorkoutSession(session)
                                    router.dismissToMain()
                                }
                            },
                            onMenuAction: handleMenuAction,
                            sessionTitle: session.title,
                            exerciseName: meta.name,
                            muscleLine: muscleLine(for: meta),
                            currentExerciseIndex: currentExerciseIndex,
                            exerciseCount: session.exercises.count,
                            completedSets: completedSetsCount,
                            totalSets: totalPlannedSets,
                            currentExerciseCompletedSets: exercise.completedSets.count,
                            currentExerciseTotalSets: exercise.plannedSets.count,
                            startedAt: session.startedAt,
                            bodyWeightKg: bodyWeightKg
                        )

                        ExerciseDemoPlayerView(
                            exerciseId: meta.id,
                            mediaProvider: environment.exerciseMediaProvider,
                            style: .fullBleed
                        )

                        setTable(exercise: exercise, meta: meta)
                            .padding(.horizontal, ForgeSpacing.s4)
                            .padding(.top, ForgeSpacing.s5)
                            .padding(.bottom, ForgeSpacing.s4)
                            .forgeExerciseContent(id: "\(currentExerciseIndex)-\(meta.id)")

                        Color.clear.frame(height: ForgeSpacing.s4)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: currentExerciseIndex) { _, _ in
                    withAnimation(ForgeMotion.exercise) {
                        proxy.scrollTo("sessionTop", anchor: .top)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { dismissKeyboard() }

            sessionActionBar(exercise: exercise, meta: meta)

            if isResting {
                restTimerBar
                    .transition(ForgeMotion.slideUp)
            }
        }
        .animation(ForgeMotion.exercise, value: currentExerciseIndex)
        .animation(ForgeMotion.standard, value: isResting)
        .sheet(isPresented: $showSwapSheet) {
            if let exercise = currentExercise {
                SwapExerciseSheet(
                    currentExerciseId: exercise.exerciseId,
                    substitutionGroup: swapGroup(for: exercise.exerciseId),
                    substitutes: swapCandidates(for: exercise.exerciseId)
                ) { substitute in
                    swapExercise(to: substitute.id)
                }
            }
        }
    }

    private func sessionActionBar(exercise: WorkoutExercise, meta: Exercise) -> some View {
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

        return VStack(spacing: ForgeSpacing.s3) {
            Divider()

            ForgeButton(title: "Complete Set", style: .accent) {
                completeCurrentSet(exercise: exercise, meta: meta, showWeightInput: showWeightInput)
            }

            HStack(spacing: ForgeSpacing.s5) {
                sessionTextAction("Add Set") { addSet(exercise: exercise) }
                sessionTextAction("Skip") { skipExercise() }
                sessionTextAction("Swap") { showSwapSheet = true }
            }
        }
        .padding(.horizontal, ForgeSpacing.s4)
        .padding(.top, ForgeSpacing.s3)
        .padding(.bottom, ForgeSpacing.s4)
        .background(ForgeColors.background)
    }

    private func sessionTextAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ForgeTypography.label)
                .foregroundStyle(ForgeColors.textSecondary)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .frame(minHeight: ForgeTarget.min)
    }

    private func handleMenuAction(_ action: WorkoutSessionMenuAction) {
        switch action {
        case .previewWorkout:
            showPreview = true
        case .workoutExplanation:
            showExplanation = true
        case .endWorkout:
            showEndConfirmation = true
        case .cancelWorkout:
            showCancelConfirmation = true
        }
    }

    private func muscleLine(for meta: Exercise) -> String {
        (meta.primaryMuscles + meta.secondaryMuscles).map(\.displayName).joined(separator: " · ")
    }

    private func swapGroup(for exerciseId: String) -> ExerciseSubstitutionGroup? {
        swapResolver?.substitutionGroup(for: exerciseId)
    }

    private func swapCandidates(for exerciseId: String) -> [Exercise] {
        let used = Set(session.exercises.map(\.exerciseId))
        return swapResolver?.swapCandidates(for: exerciseId, workoutExerciseIds: used) ?? []
    }

    private func swapExercise(to newExerciseId: String) {
        guard session.exercises.indices.contains(currentExerciseIndex) else { return }
        let existing = session.exercises[currentExerciseIndex]
        session.exercises[currentExerciseIndex] = WorkoutExercise(
            id: existing.id,
            exerciseId: newExerciseId,
            orderIndex: existing.orderIndex,
            plannedSets: existing.plannedSets,
            completedSets: [],
            restSeconds: existing.restSeconds
        )
        weightTexts = [:]
        repsTexts = [:]
        optionalLoadEnabledByExerciseId[existing.id] = false
        environment.scheduleWorkoutSessionSave(session)
    }

    private func setTable(exercise: WorkoutExercise, meta: Exercise) -> some View {
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
                setTableColumnHeader(showWeightInput: showWeightInput)

                Rectangle()
                    .fill(ForgeColors.border)
                    .frame(height: ForgeBorder.hairline)

                ForEach(Array(exercise.plannedSets.enumerated()), id: \.element.id) { index, planned in
                    let completed = exercise.completedSets.first { $0.setIndex == index }
                    let isActive = index == activeSetIndex && completed == nil
                    let isDone = completed != nil

                    setRow(
                        exerciseId: exercise.id,
                        index: index,
                        warmupsAtStart: warmupsAtStart,
                        planned: planned,
                        completed: completed,
                        isActive: isActive,
                        isDone: isDone,
                        showWeightInput: showWeightInput
                    )

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

    private func setTableColumnHeader(showWeightInput: Bool) -> some View {
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
                Text(showWeightInput ? "KG" : "BW")
                    .frame(width: ForgeSetTableLayout.weightFieldWidth)
                Text("REPS")
                    .frame(width: ForgeSetTableLayout.repsFieldWidth)
            }
            .font(ForgeTypography.tabLabel)
            .tracking(ForgeTracking.tight)
            .foregroundStyle(ForgeColors.textSecondary)
        }
        .padding(.horizontal, ForgeSpacing.s4)
        .padding(.vertical, ForgeSpacing.s2)
        .background(ForgeColors.surface.opacity(0.35))
    }

    private func setRow(
        exerciseId: UUID,
        index: Int,
        warmupsAtStart: Int,
        planned: PlannedSet,
        completed: CompletedSet?,
        isActive: Bool,
        isDone: Bool,
        showWeightInput: Bool
    ) -> some View {
        HStack(spacing: ForgeSpacing.s3) {
            Text(planned.isWarmup ? "W" : "\(index - warmupsAtStart + 1)")
                .font(ForgeTypography.metric)
                .foregroundStyle(
                    planned.isWarmup
                        ? (isDone ? ForgeColors.textSecondary : ForgeColors.textPrimary)
                        : (isDone ? ForgeColors.accentGreen : (isActive ? ForgeColors.textPrimary : ForgeColors.textSecondary))
                )
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(targetText(planned, showWeightInput: showWeightInput))
                    .font(ForgeTypography.body)
                    .foregroundStyle(isDone ? ForgeColors.textSecondary : ForgeColors.textPrimary)
                if isActive {
                    Text(planned.isWarmup ? "Warm-up set" : "Current set")
                        .font(ForgeTypography.tabLabel)
                        .foregroundStyle(ForgeColors.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: ForgeSetTableLayout.fieldSpacing) {
                if showWeightInput {
                    ForgeSetMetricField(
                        label: "KG",
                        text: bindingWeight(
                            exerciseId: exerciseId,
                            planned: planned,
                            setIndex: index,
                            completed: completed,
                            showWeightInput: showWeightInput
                        ),
                        width: ForgeSetTableLayout.weightFieldWidth,
                        isActive: isActive
                    )
                } else {
                    Text("BW")
                        .font(ForgeTypography.metric)
                        .foregroundStyle(isActive || isDone ? ForgeColors.textPrimary : ForgeColors.textSecondary)
                        .frame(width: ForgeSetTableLayout.weightFieldWidth, alignment: .center)
                }

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
    }

    private func targetText(_ planned: PlannedSet, showWeightInput: Bool) -> String {
        let range = "\(planned.targetRepsMin)–\(planned.targetRepsMax)"
        guard showWeightInput == true else {
            if planned.isWarmup { return "Warm-up · BW · \(range)" }
            return "BW · \(range)"
        }

        if let wKg = planned.targetWeightKg {
            let w = "\(Int(wKg))kg × "
            if planned.isWarmup {
                return "Warm-up · \(w)\(range)"
            }
            return "\(w)\(range)"
        } else {
            // Optional mode: user may enable weight input, but planned weight is initially unknown.
            if planned.isWarmup { return "Warm-up · Load · \(range)" }
            return "Load · \(range)"
        }
    }

    private func bindingWeight(
        exerciseId: UUID,
        planned: PlannedSet,
        setIndex: Int,
        completed: CompletedSet?,
        showWeightInput: Bool
    ) -> Binding<String> {
        Binding(
            get: {
                weightTexts[planned.id]
                    ?? completed?.weightKg.map { String(format: "%.1f", $0) }
                    ?? planned.targetWeightKg.map { String(format: "%.0f", $0) }
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

    private func bindingReps(
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

    private func updateCompletedSet(
        exerciseId: UUID,
        setIndex: Int,
        weightKg: Double? = nil,
        reps: Int? = nil
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
        environment.scheduleWorkoutSessionSave(session)
    }

    private func dismissKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
#endif
    }

    private var restTimerBar: some View {
        HStack(spacing: ForgeSpacing.s4) {
            VStack(alignment: .leading, spacing: 2) {
                Text("REST")
                    .font(ForgeTypography.tabLabel)
                    .tracking(ForgeTracking.tight)
                Text(WorkoutSessionCalculator.formattedElapsed(seconds: restSecondsRemaining))
                    .font(ForgeTypography.metric)
                    .contentTransition(.numericText())
            }
            Spacer()
            Button("+30s") { restSecondsRemaining += 30 }
                .font(ForgeTypography.label)
            Button("Skip") { isResting = false }
                .font(ForgeTypography.label.weight(.semibold))
        }
        .padding(.horizontal, ForgeSpacing.s4)
        .padding(.vertical, ForgeSpacing.s3)
        .background(ForgeColors.surfaceInverse)
        .foregroundStyle(ForgeColors.textOnInverse)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard isResting, restSecondsRemaining > 0 else {
                if isResting && restSecondsRemaining == 0 {
                    isResting = false
                }
                return
            }
            restSecondsRemaining -= 1
        }
    }

    private func completeCurrentSet(
        exercise: WorkoutExercise,
        meta: Exercise,
        showWeightInput: Bool
    ) {
        dismissKeyboard()
        guard let idx = session.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        let setIndex = session.exercises[idx].completedSets.count
        guard setIndex < session.exercises[idx].plannedSets.count else { return }
        let planned = session.exercises[idx].plannedSets[setIndex]
        let weight: Double? = showWeightInput
            ? (Double(weightTexts[planned.id] ?? "") ?? planned.targetWeightKg)
            : nil
        let reps = Int(repsTexts[planned.id] ?? "") ?? planned.targetRepsMin
        let completed = CompletedSet(setIndex: setIndex, weightKg: weight, reps: reps, isWarmup: planned.isWarmup)
        session.exercises[idx].completedSets.append(completed)
        environment.scheduleWorkoutSessionSave(session)

        let allSetsDone = session.exercises[idx].completedSets.count >= session.exercises[idx].plannedSets.count
        if allSetsDone {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                advanceExercise()
            }
        } else {
            restSecondsRemaining = planned.isWarmup
                ? GenerationConstants.Warmup.restSeconds
                : session.exercises[idx].restSeconds
            isResting = true
        }
    }

    private func addSet(exercise: WorkoutExercise) {
        guard let idx = session.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        let last = session.exercises[idx].plannedSets.last ?? PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        session.exercises[idx].plannedSets.append(last)
    }

    private func skipExercise() {
        guard let idx = session.exercises.indices.contains(currentExerciseIndex) ? currentExerciseIndex : nil else { return }
        session.exercises[idx].wasSkipped = true
        advanceExercise()
    }

    private func advanceExercise() {
        if currentExerciseIndex + 1 < session.exercises.count {
            withAnimation(ForgeMotion.exercise) {
                currentExerciseIndex += 1
                isResting = false
                weightTexts = [:]
                repsTexts = [:]
            }
        } else {
            finishWorkout()
        }
    }

    private func finishWorkout() {
        session.status = .completed
        session.completedAt = Date()
        Task { @MainActor in
            try? await environment.saveWorkoutSessionImmediately(session)
            progressionNotes = await environment.applyWorkoutSessionCompletion(session)
            withAnimation(ForgeMotion.standard) {
                showCompletion = true
            }
        }
    }

    private func loadExercises() async {
        let used = Set(session.exercises.map(\.exerciseId))
        guard let resolver = await environment.loadExerciseSwapResolver(usedExerciseIds: used) else { return }
        swapResolver = resolver
        allExercises = resolver.allExercises
        substitutionGroups = resolver.substitutionGroups
        exerciseMap = resolver.exerciseMap
    }
}

struct WorkoutCompletionView: View {
    let session: WorkoutSession
    var progressionNotes: [String] = []
    let onDone: () -> Void

    private var volume: Double {
        WorkoutSessionCalculator.completedVolumeKg(session: session)
    }

    private var duration: Int {
        guard let start = session.startedAt, let end = session.completedAt else { return session.estimatedDurationMinutes }
        return Int(end.timeIntervalSince(start) / 60)
    }

    var body: some View {
        VStack(spacing: ForgeSpacing.s6) {
            Text("WORKOUT COMPLETE")
                .font(ForgeTypography.heroMetric)
                .tracking(ForgeTracking.eyebrowWide)
                .foregroundStyle(ForgeColors.accentGreen)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            ForgeCard {
                completionMetricsRow
            }

            if !progressionNotes.isEmpty {
                ForgeCard {
                    ForgeSectionHeader(title: "Progression", accent: ForgeColors.accentGreen)
                    ForEach(progressionNotes, id: \.self) { note in
                        Text("· \(note)")
                            .font(ForgeTypography.body)
                            .foregroundStyle(ForgeColors.textSecondary)
                    }
                }
                .padding(.top, ForgeSpacing.s2)
            }

            Spacer(minLength: 0)

            ForgeButton(title: "Done", style: .accent, action: onDone)
        }
        .padding(.horizontal, ForgeSpacing.s5)
        .padding(.top, ForgeSpacing.s6)
        .padding(.bottom, ForgeSpacing.s5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ForgeColors.background)
        .forgeSuccessHaptic(value: session.id)
    }

    private var completionMetricsRow: some View {
        let setsCount = WorkoutSessionCalculator.completedSetCount(session: session)

        return HStack(spacing: 0) {
            metricColumn(
                label: "Volume",
                value: "\(Int(volume))kg",
                accent: ForgeColors.accent
            )

            metricDivider

            metricColumn(
                label: "Sets",
                value: "\(setsCount)",
                accent: ForgeColors.accentGreen
            )

            metricDivider

            metricColumn(
                label: "Duration",
                value: "\(duration) min",
                accent: ForgeColors.accentAmber
            )
        }
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(ForgeColors.border)
            .frame(width: 1, height: 44)
            .padding(.vertical, 4)
    }

    private func metricColumn(label: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(ForgeTypography.caption)
                .tracking(ForgeTracking.eyebrowWide)
                .foregroundStyle(ForgeColors.muted)
            Text(value)
                .font(ForgeTypography.monoMetric)
                .foregroundStyle(accent)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
