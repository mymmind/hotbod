// swiftlint:disable function_body_length file_length function_parameter_count
import SwiftUI

private struct SessionSwapTarget: Identifiable {
    let index: Int
    var id: Int { index }
}

// swiftlint:disable:next type_body_length
struct WorkoutSessionView: View {
    @Environment(AppEnvironment.self) var environment
    @Environment(AppRouter.self) var router
    @Environment(\.forgeFeedback) var feedback
    @Environment(\.scenePhase) private var scenePhase
    @State var session: WorkoutSession
    @State var currentExerciseIndex: Int
    @State var furthestExerciseIndex: Int
    @State var weightTexts: [UUID: String] = [:]
    @State var repsTexts: [UUID: String] = [:]
    @State private var pendingRpeBySetId: [UUID: Double] = [:]
    @State var shouldAdvanceExerciseAfterRest = false
    // For `loadTrackingMode == .optional` exercises: user can opt into external load input.
    @State private var optionalLoadEnabledByExerciseId: [UUID: Bool] = [:]
    @State var restEndDate: Date?
    @State var isResting = false
    @State private var showCompletion = false
    @State var exerciseMap: [String: Exercise] = [:]
    @State private var swapTarget: SessionSwapTarget?
    @State private var progressionNotes: [String] = []
    @State private var allExercises: [Exercise] = []
    @State private var substitutionGroups: [ExerciseSubstitutionGroup] = []
    @State private var swapResolver: ExerciseSwapResolver?
    @State private var showPreview = false
    @State private var showExplanation = false
    @State private var showEndConfirmation = false
    @State private var showCancelConfirmation = false
    @State var exerciseStatsById: [String: UserExerciseStats] = [:]
    @State var flashSetId: UUID?
    @State var prSetId: UUID?
    @State var restTotalSeconds = 0
    @State var restWarningPlayed = false
    @State private var completionWorkoutStreak = 0
    @State var durationTexts: [UUID: String] = [:]
    @State var distanceTexts: [UUID: String] = [:]
    @State var showRIRPrompt = false
    @State var pendingPostSetAction: PendingPostSetAction?
    @State var rirPromptExerciseIndex: Int?
    @State var rirPromptSetIndex: Int?
    @State var showExerciseComplete = false
    @State private var showExerciseInfo = false
    @State private var showAddExercise = false
    @State private var sessionResourcesLoaded = false

    init(session: WorkoutSession) {
        _session = State(initialValue: session)
        let resumeIndex = WorkoutSessionCalculator.currentExerciseIndex(for: session)
        _currentExerciseIndex = State(initialValue: resumeIndex)
        _furthestExerciseIndex = State(initialValue: resumeIndex)
        let activeRestEnd = session.activeRestEndAt
        let resting = activeRestEnd.map { $0 > Date() } ?? false
        _restEndDate = State(initialValue: resting ? activeRestEnd : nil)
        _isResting = State(initialValue: resting)
        _restTotalSeconds = State(initialValue: session.activeRestTotalSeconds ?? 0)
        _shouldAdvanceExerciseAfterRest = State(initialValue: session.activeRestAdvancesExercise ?? false)
    }

    var currentExercise: WorkoutExercise? {
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
                Group {
                    if UITestConfiguration.isUITesting {
                        uitestCompletionView
                    } else {
                        WorkoutCompletionView(
                            session: session,
                            progressionNotes: progressionNotes,
                            workoutStreak: completionWorkoutStreak,
                            exerciseMap: exerciseMap
                        ) {
                            Task {
                                await environment.refreshWorkoutAfterSession(session)
                                router.dismissToMain()
                            }
                        }
                    }
                }
                .transition(ForgeMotion.rise)
                .id("completion")
            } else if let exercise = currentExercise, let meta = exerciseMap[exercise.exerciseId] {
                sessionContent(exercise: exercise, meta: meta)
                    .transition(UITestConfiguration.isUITesting ? .identity : ForgeMotion.appear)
                    .id("session")
            } else {
                ProgressView()
                    .accessibilityIdentifier("session.loading")
                    .id("loading")
            }
        }
        .animation(UITestConfiguration.isUITesting ? nil : ForgeMotion.standard, value: showCompletion)
        .animation(UITestConfiguration.isUITesting ? nil : ForgeMotion.exercise, value: currentExerciseIndex)
        .background(ForgeColors.background)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await environment.setActiveWorkoutSession(session)
            await loadExercises()
        }
        .sheet(isPresented: $showPreview) {
            ActiveWorkoutPreviewView(
                session: session,
                currentExerciseIndex: currentExerciseIndex,
                furthestExerciseIndex: furthestExerciseIndex,
                exerciseMap: exerciseMap,
                canSwapAtIndex: canSwapExercise(at:),
                onSelectExercise: { index in
                    goToExercise(at: index)
                    showPreview = false
                },
                onSwapExercise: { index in
                    presentSwapSheet(for: index)
                    showPreview = false
                }
            )
        }
        .sheet(isPresented: $showExplanation) {
            WorkoutExplanationSheet(
                title: session.title,
                rationale: environment.todayWorkout?.rationale ?? "",
                selectionRationale: environment.todayWorkout?.selectionRationale ?? [],
                safetyNotes: environment.todayWorkout?.safetyNotes ?? []
            )
        }
        .confirmationDialog("End Workout?", isPresented: $showEndConfirmation, titleVisibility: .visible) {
            Button("End & Save Progress") { finishWorkout() }
                .accessibilityIdentifier("session.endWorkout.save")
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
                            onExit: exitWorkoutForUITest,
                            onMenuAction: handleMenuAction,
                            onPreviousExercise: goToPreviousExercise,
                            onNextExercise: goToNextExercise,
                            onSelectExercise: { goToExercise(at: $0) },
                            onShowExerciseInfo: { showExerciseInfo = true },
                            sessionTitle: session.title,
                            exerciseName: meta.name,
                            muscleLine: muscleLine(for: meta),
                            currentExerciseIndex: currentExerciseIndex,
                            furthestExerciseIndex: furthestExerciseIndex,
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
                ForgeRestTimerBar(
                    secondsRemaining: restSecondsRemaining,
                    totalSeconds: max(restTotalSeconds, 1),
                    onAddTime: { addRestTime() },
                    onSkip: { endRestTimer(skipped: true) }
                )
                .transition(ForgeMotion.slideUp)
            }

            if showExerciseComplete, let exercise = currentExercise, let meta = exerciseMap[exercise.exerciseId] {
                let summary = exerciseCompleteSummary(for: exercise, meta: meta)
                ExerciseCompleteInterstitial(
                    exerciseName: meta.name,
                    setsCompleted: summary.setsCompleted,
                    volumeKg: summary.volumeKg,
                    bestSetDescription: summary.bestSetDescription,
                    averageRPE: summary.averageRPE,
                    onContinue: {
                        showExerciseComplete = false
                        advanceExercise()
                    }
                )
                .transition(ForgeMotion.rise)
            }
        }
        .animation(UITestConfiguration.isUITesting ? nil : ForgeMotion.exercise, value: currentExerciseIndex)
        .animation(UITestConfiguration.isUITesting ? nil : ForgeMotion.standard, value: isResting)
        .background {
            if UITestConfiguration.isUITesting, sessionResourcesLoaded {
                Color.clear
                    .frame(width: 0, height: 0)
                    .accessibilityIdentifier("uitest.session.ready")
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            handleRestTimerTick()
            processWatchCommand(showWeightInput: showWeightInput(for: exercise, meta: meta))
        }
        .onAppear {
            restoreRestTimerIfNeeded()
            syncWatchSnapshot()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                restoreRestTimerIfNeeded()
            }
        }
        .sheet(isPresented: $showExerciseInfo) {
            if let exercise = currentExercise,
               let meta = exerciseMap[exercise.exerciseId] {
                NavigationStack {
                    ExerciseDetailView(exerciseId: meta.id)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showExerciseInfo = false }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showAddExercise) {
            AddExerciseSheet(
                exercises: allExercises,
                usedExerciseIds: Set(session.exercises.map(\.exerciseId))
            ) { selected in
                appendExercise(selected)
            }
        }
        .sheet(isPresented: $showRIRPrompt, onDismiss: {
            if pendingPostSetAction != nil {
                finishRIRPromptFlow()
            }
        }) {
            ForgeRIRPromptSheet(
                onSelect: { rir in
                    applyRIRSelection(rir)
                },
                onSkip: {
                    finishRIRPromptFlow()
                }
            )
        }
        .onChange(of: currentExerciseIndex) { _, _ in syncWatchSnapshot() }
        .sheet(item: $swapTarget) { target in
            swapSheetContent(for: target)
        }
        .fullScreenCover(item: UITestConfiguration.isUITesting ? $swapTarget : .constant(nil)) { target in
            swapSheetContent(for: target)
        }
    }

    private func sessionActionBar(exercise: WorkoutExercise, meta: Exercise) -> some View {
        let showWeightInput = showWeightInput(for: exercise, meta: meta)

        return VStack(spacing: ForgeSpacing.s3) {
            Divider()

            if UITestConfiguration.isUITesting {
                HStack(spacing: ForgeSpacing.s3) {
                    ForgeButton(
                        title: "Exit",
                        style: .secondary,
                        accessibilityIdentifier: "session.ui.exitWorkout"
                    ) {
                        exitWorkoutForUITest()
                    }
                    ForgeButton(
                        title: "End",
                        style: .secondary,
                        accessibilityIdentifier: "session.ui.endWorkout"
                    ) {
                        finishWorkout()
                    }
                }
            }

            ForgeButton(
                title: "Complete Set",
                style: .accent,
                accessibilityIdentifier: "session.completeSet"
            ) {
                completeCurrentSet(exercise: exercise, meta: meta, showWeightInput: showWeightInput)
            }

            HStack(spacing: ForgeSpacing.s5) {
                sessionTextAction("Add Set", identifier: "session.addSet") { addSet(exercise: exercise) }
                if !UITestConfiguration.isUITesting {
                    sessionTextAction("Add Exercise", identifier: "session.addExercise") { showAddExercise = true }
                }
                sessionTextAction("Skip", identifier: "session.skipExercise") { skipExercise() }
                sessionTextAction("Swap", identifier: "session.swapExercise") { presentSwapSheet(for: currentExerciseIndex) }
                if canGroupWithNext(exercise: exercise) {
                    sessionTextAction("Group", identifier: "session.groupWithNext") { groupWithNextExercise() }
                }
                if exercise.groupId != nil {
                    sessionTextAction("Ungroup", identifier: "session.ungroup") { ungroupCurrentExercise() }
                }
            }
        }
        .padding(.horizontal, ForgeSpacing.s4)
        .padding(.top, ForgeSpacing.s3)
        .padding(.bottom, ForgeSpacing.s4)
        .background(ForgeColors.background)
    }

    private func sessionTextAction(
        _ title: String,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(ForgeTypography.label)
                .foregroundStyle(ForgeColors.textSecondary)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: ForgeTarget.min)
        .contentShape(Rectangle())
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier ?? title)
    }

    private func exitWorkoutForUITest() {
        if UITestConfiguration.isUITesting {
            router.dismissToMain()
            return
        } else {
            Task {
                await environment.pauseWorkoutSession(session)
                router.dismissToMain()
            }
        }
    }

    private func handleMenuAction(_ action: WorkoutSessionMenuAction) {
        switch action {
        case .previewWorkout:
            showPreview = true
        case .swapExercise:
            presentSwapSheet(for: currentExerciseIndex)
        case .workoutExplanation:
            showExplanation = true
        case .endWorkout:
            if UITestConfiguration.isUITesting {
                finishWorkout()
            } else {
                showEndConfirmation = true
            }
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

    private func canSwapExercise(at index: Int) -> Bool {
        guard session.exercises.indices.contains(index) else { return false }
        let exercise = session.exercises[index]
        guard !exercise.wasSkipped else { return false }
        return exercise.completedSets.isEmpty || index == currentExerciseIndex
    }


    @ViewBuilder
    private func swapSheetContent(for target: SessionSwapTarget) -> some View {
        let exercise = session.exercises[target.index]
        SwapExerciseSheet(
            currentExerciseId: exercise.exerciseId,
            substitutionGroup: swapGroup(for: exercise.exerciseId),
            substitutes: swapCandidates(for: exercise.exerciseId)
        ) { substitute in
            swapExercise(at: target.index, to: substitute.id)
        }
    }

    private func presentSwapSheet(for index: Int) {
        if !UITestConfiguration.isUITesting {
            guard canSwapExercise(at: index) else { return }
        }
        swapTarget = SessionSwapTarget(index: index)
    }

    private func swapExercise(at index: Int, to newExerciseId: String) {
        guard session.exercises.indices.contains(index),
              let substitute = exerciseMap[newExerciseId] else { return }
        let existing = session.exercises[index]
        let experience = environment.userProfile?.experienceLevel ?? .intermediate
        let replannedSets = ExerciseSwapReplanner.replannedSets(
            preservingStructureFrom: existing.plannedSets,
            for: substitute,
            stats: exerciseStatsById[newExerciseId],
            bodyweightKg: bodyWeightKg,
            experience: experience,
            weightCeilings: environment.userProfile?.maxAvailableWeightKg ?? [:]
        )
        session.exercises[index] = WorkoutExercise(
            id: existing.id,
            exerciseId: newExerciseId,
            orderIndex: existing.orderIndex,
            plannedSets: replannedSets,
            completedSets: [],
            restSeconds: existing.restSeconds,
            groupId: existing.groupId
        )
        if index == currentExerciseIndex {
            weightTexts = [:]
            repsTexts = [:]
            pendingRpeBySetId = [:]
            durationTexts = [:]
            distanceTexts = [:]
            optionalLoadEnabledByExerciseId[existing.id] = false
        }
        feedback.play(.exerciseSwap)
        environment.scheduleWorkoutSessionSave(session)
        Task {
            await environment.syncTodayWorkoutExerciseSwap(
                orderIndex: existing.orderIndex,
                newExerciseId: newExerciseId,
                plannedSets: replannedSets
            )
        }
        swapTarget = nil
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

    private func setTableColumnHeader(exercise: WorkoutExercise, meta: Exercise, showWeightInput: Bool) -> some View {
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

    private func setRow(
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

    private func setLabel(planned: PlannedSet, index: Int, warmupsAtStart: Int) -> String {
        if planned.isWarmup { return "W" }
        if planned.isCooldown { return "C" }
        return "\(index - warmupsAtStart + 1)"
    }

    private func activeSetSubtitle(for planned: PlannedSet) -> String {
        if planned.isMaxEffort { return "Max effort · AMRAP" }
        if planned.isWarmup { return "Warm-up set" }
        if planned.isCooldown { return "Cooldown set" }
        return "Current set"
    }

    private func activeSetSubtitleColor(for planned: PlannedSet) -> Color {
        if planned.isMaxEffort { return ForgeColors.accentAmber }
        if planned.isCooldown { return ForgeColors.accentGreen }
        return ForgeColors.accent
    }

    private func rpePickerRow(
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

    private func bindingDuration(
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

    private func bindingDistance(
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

    func completeCurrentSet(
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
        let reps = Int(repsTexts[planned.id] ?? "") ?? (planned.targetRepsMin > 0 ? planned.targetRepsMin : 1)
        let durationSeconds = Int(durationTexts[planned.id] ?? "")
            ?? planned.targetDurationSeconds
        let distanceMeters = Double(distanceTexts[planned.id] ?? "")
            ?? planned.targetDistanceMeters
        let loggedRPE = (planned.isWarmup || planned.isCooldown) ? nil : pendingRpeBySetId[planned.id]
        let needsRIRPrompt = !planned.isWarmup
            && !planned.isCooldown
            && usesRepMetric(for: meta)
            && loggedRPE == nil
        let completed = CompletedSet(
            setIndex: setIndex,
            weightKg: weight,
            reps: usesRepMetric(for: meta) ? reps : 0,
            rpe: loggedRPE,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters,
            isWarmup: planned.isWarmup,
            isCooldown: planned.isCooldown
        )
        session.exercises[idx].completedSets.append(completed)
        pendingRpeBySetId.removeValue(forKey: planned.id)
        environment.scheduleWorkoutSessionSave(session)

        let isPR = isPersonalRecord(exerciseId: exercise.exerciseId, completed: completed, showWeightInput: showWeightInput)
        flashCompletedSet(planned.id, isPR: isPR)
        feedback.play(isPR ? .personalRecord : .setComplete)

        let allSetsDone = session.exercises[idx].completedSets.count >= session.exercises[idx].plannedSets.count
        let postAction: PendingPostSetAction
        if allSetsDone {
            let transitionRest = ExerciseGroupPlanner.restBeforeAdvancing(from: idx, exercises: session.exercises)
            if transitionRest > 0 {
                postAction = .rest(seconds: transitionRest, advanceAfter: true)
            } else {
                postAction = .exerciseComplete
            }
        } else {
            let restSeconds: Int
            if planned.isWarmup {
                restSeconds = GenerationConstants.Warmup.restSeconds
            } else if planned.isCooldown {
                restSeconds = GenerationConstants.Cooldown.restSeconds
            } else {
                restSeconds = session.exercises[idx].restSeconds
            }
            postAction = .rest(seconds: restSeconds, advanceAfter: false)
        }

        if needsRIRPrompt {
            rirPromptExerciseIndex = idx
            rirPromptSetIndex = setIndex
            pendingPostSetAction = postAction
            showRIRPrompt = true
        } else {
            executePostSetAction(postAction)
        }
        syncWatchSnapshot()
    }

    func showWeightInput(for exercise: WorkoutExercise, meta: Exercise) -> Bool {
        let loadMode = meta.resolvedLoadTrackingMode
        let hasExternalLoadInHistory = exercise.completedSets.contains { $0.weightKg != nil }
            || exercise.plannedSets.contains(where: { $0.targetWeightKg != nil })
        let optionalEnabled = optionalLoadEnabledByExerciseId[exercise.id] ?? hasExternalLoadInHistory
        switch loadMode {
        case .none: return false
        case .optional: return optionalEnabled
        case .supported, .required: return true
        }
    }

    private func canGroupWithNext(exercise: WorkoutExercise) -> Bool {
        let index = currentExerciseIndex
        guard index + 1 < session.exercises.count else { return false }
        let next = session.exercises[index + 1]
        guard exercise.groupId != next.groupId else { return false }
        guard let currentMeta = exerciseMap[exercise.exerciseId],
              let nextMeta = exerciseMap[next.exerciseId] else { return false }
        return ExerciseGroupPlanner.areCompatibleForGrouping(currentMeta, nextMeta)
    }

    private func groupWithNextExercise() {
        ExerciseGroupPlanner.groupAdjacent(in: &session.exercises, at: currentExerciseIndex)
        environment.scheduleWorkoutSessionSave(session)
    }

    private func ungroupCurrentExercise() {
        ExerciseGroupPlanner.ungroup(in: &session.exercises, at: currentExerciseIndex)
        environment.scheduleWorkoutSessionSave(session)
    }

    private func addSet(exercise: WorkoutExercise) {
        guard let idx = session.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        let last = session.exercises[idx].plannedSets.last ?? PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        session.exercises[idx].plannedSets.append(last)
        environment.scheduleWorkoutSessionSave(session)
    }

    private func skipExercise() {
        guard let idx = session.exercises.indices.contains(currentExerciseIndex) ? currentExerciseIndex : nil else { return }
        session.exercises[idx].wasSkipped = true
        clearPersistedRestState()
        environment.scheduleWorkoutSessionSave(session)
        advanceExercise()
    }

    private func goToPreviousExercise() {
        goToExercise(at: currentExerciseIndex - 1)
    }

    private func goToNextExercise() {
        goToExercise(at: currentExerciseIndex + 1)
    }

    private func applyRIRSelection(_ rir: Int) {
        if let exerciseIdx = rirPromptExerciseIndex,
           let setIndex = rirPromptSetIndex,
           session.exercises.indices.contains(exerciseIdx),
           let completedIdx = session.exercises[exerciseIdx].completedSets.firstIndex(where: { $0.setIndex == setIndex }) {
            session.exercises[exerciseIdx].completedSets[completedIdx].rir = rir
            session.exercises[exerciseIdx].completedSets[completedIdx].rpe = EffortFeedbackMapping.rpe(fromRIR: rir)
            session.exercises[exerciseIdx].completedSets[completedIdx].isFailure = rir == 0
            environment.scheduleWorkoutSessionSave(session)
        }
        finishRIRPromptFlow()
    }

    func presentExerciseCompleteOrAdvance() {
        withAnimation(ForgeMotion.standard) {
            showExerciseComplete = true
        }
    }

    private func appendExercise(_ exercise: Exercise) {
        let profile = environment.userProfile
        let newExercise = SessionExercisePlanner.makeWorkoutExercise(
            exercise: exercise,
            orderIndex: session.exercises.count,
            experience: profile?.experienceLevel ?? .intermediate,
            goal: profile?.goal ?? .buildMuscle,
            bodyWeightKg: bodyWeightKg,
            stats: exerciseStatsById[exercise.id],
            weightCeilings: profile?.maxAvailableWeightKg ?? [:]
        )
        session.exercises.append(newExercise)
        exerciseMap[exercise.id] = exercise
        environment.scheduleWorkoutSessionSave(session)
        feedback.play(.exerciseSwap)
    }

    private func goToExercise(at index: Int) {
        guard session.exercises.indices.contains(index) else { return }
        guard index != currentExerciseIndex else { return }
        dismissKeyboard()
        clearPersistedRestState()
        pendingPostSetAction = nil
        withAnimation(ForgeMotion.exercise) {
            currentExerciseIndex = index
            furthestExerciseIndex = max(furthestExerciseIndex, index)
            clearMetricTexts()
            showExerciseComplete = false
        }
        environment.scheduleWorkoutSessionSave(session)
    }

    func advanceExercise() {
        showExerciseComplete = false
        pendingPostSetAction = nil
        clearPersistedRestState()
        if currentExerciseIndex + 1 < session.exercises.count {
            withAnimation(ForgeMotion.exercise) {
                currentExerciseIndex += 1
                furthestExerciseIndex = max(furthestExerciseIndex, currentExerciseIndex)
                clearMetricTexts()
            }
        } else {
            finishWorkout()
        }
    }


    private var uitestCompletionView: some View {
        VStack(spacing: ForgeSpacing.s6) {
            Text(L10n.Workout.completeTitle)
                .font(ForgeTypography.heroMetric)
                .foregroundStyle(ForgeColors.accentGreen)
                .accessibilityIdentifier("session.workoutComplete")
            ForgeButton(
                title: "Done",
                style: .accent,
                accessibilityIdentifier: "session.finishWorkout"
            ) {
                Task {
                    await environment.refreshWorkoutAfterSession(session)
                    router.dismissToMain()
                }
            }
        }
        .padding(ForgeSpacing.s5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ForgeColors.background)
    }

    private func finishWorkout() {
        session.status = .completed
        session.completedAt = Date()
        clearPersistedRestState()
        pendingPostSetAction = nil
        if UITestConfiguration.isUITesting {
            showCompletion = true
        }
        Task { @MainActor in
            if UITestConfiguration.isUITesting {
                await Task.yield()
            }
            try? await environment.saveWorkoutSessionImmediately(session)
            progressionNotes = await environment.applyWorkoutSessionCompletion(session)
            let sessions = await environment.fetchWorkoutSessions()
            completionWorkoutStreak = TrainingStreakCalculator.workoutStreak(sessions: sessions)
            feedback.play(.workoutComplete)
            if !UITestConfiguration.isUITesting {
                withAnimation(ForgeMotion.standard) {
                    showCompletion = true
                }
            }
        }
    }

  private func loadExercises() async {
        let used = Set(session.exercises.map(\.exerciseId))
        if UITestConfiguration.isUITesting {
            let all = await environment.fetchAllExercises()
            exerciseMap = ExerciseCatalog.indexedById(all)
            allExercises = all
            substitutionGroups = (try? await environment.exerciseRepository.fetchSubstitutionGroups()) ?? []
            swapResolver = await environment.loadExerciseSwapResolver(usedExerciseIds: used)
            let stats = await environment.fetchExerciseStats()
            exerciseStatsById = Dictionary(uniqueKeysWithValues: stats.map { ($0.exerciseId, $0) })
            for exerciseId in used where exerciseMap[exerciseId] == nil {
                if let exercise = ExerciseSeedLoader.load().first(where: { $0.id == exerciseId }) {
                    exerciseMap[exerciseId] = exercise
                }
            }
            sessionResourcesLoaded = true
            return
        }
        if let resolver = await environment.loadExerciseSwapResolver(usedExerciseIds: used) {
            swapResolver = resolver
            allExercises = resolver.allExercises
            substitutionGroups = resolver.substitutionGroups
            exerciseMap = resolver.exerciseMap
        }
        for exerciseId in used where exerciseMap[exerciseId] == nil {
            if let exercise = await environment.fetchExercise(id: exerciseId) {
                exerciseMap[exerciseId] = exercise
            }
        }
        let stats = await environment.fetchExerciseStats()
        exerciseStatsById = Dictionary(uniqueKeysWithValues: stats.map { ($0.exerciseId, $0) })
        sessionResourcesLoaded = true
    }
}
