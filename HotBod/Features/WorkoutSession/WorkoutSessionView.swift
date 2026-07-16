// swiftlint:disable function_body_length
import SwiftUI

struct SessionSwapTarget: Identifiable {
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
    @State var pendingRpeBySetId: [UUID: Double] = [:]
    @State var shouldAdvanceExerciseAfterRest = false
    // For `loadTrackingMode == .optional` exercises: user can opt into external load input.
    @State var optionalLoadEnabledByExerciseId: [UUID: Bool] = [:]
    @State var restEndDate: Date?
    @State var isResting = false
    @State var showCompletion = false
    @State var exerciseMap: [String: Exercise] = [:]
    @State var swapTarget: SessionSwapTarget?
    @State var progressionNotes: [String] = []
    @State var allExercises: [Exercise] = []
    @State var substitutionGroups: [ExerciseSubstitutionGroup] = []
    @State var swapResolver: ExerciseSwapResolver?
    @State private var showPreview = false
    @State private var showExplanation = false
    @State private var showEndConfirmation = false
    @State private var showCancelConfirmation = false
    @State var exerciseStatsById: [String: UserExerciseStats] = [:]
    @State var flashSetId: UUID?
    @State var prSetId: UUID?
    @State var restTotalSeconds = 0
    @State var restTimerKind: RestTimerKind = .setRest
    @State var restFeedbackCuesPlayed: Set<RestTimerFeedbackCue> = []
    @State var completionWorkoutStreak = 0
    @State var durationTexts: [UUID: String] = [:]
    @State var distanceTexts: [UUID: String] = [:]
    @State var showRIRPrompt = false
    @State var pendingPostSetAction: PendingPostSetAction?
    @State var rirPromptExerciseIndex: Int?
    @State var rirPromptSetIndex: Int?
    @State var showExerciseComplete = false
    @State private var showExerciseInfo = false
    @State private var showAddExercise = false
    @State var sessionResourcesLoaded = false

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

    var bodyWeightKg: Double {
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
        .overlay(alignment: .top) {
            if showCompletion {
                Text(L10n.Workout.completeTitle)
                    .font(ForgeTypography.heroMetric)
                    .foregroundStyle(ForgeColors.accentGreen)
                    .padding(.top, ForgeSpacing.s6)
                    .accessibilityIdentifier("session.workoutComplete")
            }
        }
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
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    ForgeRestTimerBar(
                        secondsRemaining: restSecondsRemaining(at: context.date),
                        totalSeconds: max(restTotalSeconds, 1),
                        onAddTime: { addRestTime() },
                        onSkip: { endRestTimer(skipped: true) }
                    )
                }
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
            switch phase {
            case .active:
                restoreRestTimerIfNeeded()
            case .background:
                persistMetricDrafts()
                Task { await environment.flushPendingWorkoutSessionSave() }
            default:
                break
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
    }

    private func sessionActionBar(exercise: WorkoutExercise, meta: Exercise) -> some View {
        let showWeightInput = showWeightInput(for: exercise, meta: meta)

        return VStack(spacing: ForgeSpacing.s3) {
            Divider()

            if UITestConfiguration.isUITesting {
                HStack(spacing: ForgeSpacing.s3) {
                    Button("Exit Session") { exitWorkoutForUITest() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("session.ui.exitWorkout")
                    Button("End Workout") {
                        showExerciseComplete = false
                        showRIRPrompt = false
                        showCompletion = true
                        session.status = .completed
                        session.completedAt = Date()
                        Task { await persistWorkoutCompletion() }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("session.ui.endWorkout")
                }
            }

            ForgeButton(
                title: "Complete Set",
                style: .accent,
                accessibilityIdentifier: "session.completeSet",
                playsFeedback: false
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
                persistMetricDrafts()
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

}
