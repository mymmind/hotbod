import SwiftUI

struct TrainView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var sessions: [WorkoutSession] = []
    @State private var activeSession: WorkoutSession?
    @State private var completedSession: WorkoutSession?
    @State private var showLibrary = false
    @State private var showSummary = false

    @State private var isRegenerating = false
    @State private var regenSpin = false
    @State private var showGenerationFailureAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForgeScreenHeader(
                        title: "Train",
                        eyebrow: "Program",
                        subtitle: trainHeaderSubtitle
                    )
                    if let workout = environment.todayWorkout {
                        workoutCard(workout)
                            .forgeAnimatedContent(id: workout.id)
                    } else {
                        VStack(spacing: 16) {
                            EmptyStateView(
                                title: "No workout yet",
                                message: "Generate today’s session from your training plan."
                            ) {
                                if let profile = environment.userProfile {
                                    Task { _ = await environment.regenerateTodayWorkout(profile: profile) }
                                }
                            }
                        }
                        .padding()
                    }
                    VStack(spacing: 16) {
                        historySection
                        librarySection
                    }
                    .padding()
                }
                .animation(ForgeMotion.standard, value: environment.todayWorkout?.id)
            }
            .background(ForgeColors.background)
            .forgeFloatingTabBarClearance()
            .forgeScreenNavigationHidden()
            .navigationDestination(isPresented: $showLibrary) {
                ExerciseLibraryView()
            }
            .navigationDestination(for: UUID.self) { sessionId in
                if let session = sessions.first(where: { $0.id == sessionId }) {
                    WorkoutHistoryDetailView(session: session)
                } else {
                    ContentUnavailableView(
                        "Workout Not Found",
                        systemImage: "exclamationmark.triangle",
                        description: Text("This workout is no longer available in local history.")
                    )
                }
            }
            .navigationDestination(for: String.self) { exerciseId in
                ExerciseDetailView(exerciseId: exerciseId)
            }
            .task {
                await loadSessions()
                await loadActiveSession()
                await loadCompletedSession()
            }
            .onChange(of: router.route) { _, newRoute in
                if case .main = newRoute {
                    Task {
                        await loadSessions()
                        await loadActiveSession()
                        await loadCompletedSession()
                    }
                }
            }
            .onChange(of: environment.isTodayWorkoutCompleted) { _, _ in
                Task {
                    await loadCompletedSession()
                    await loadActiveSession()
                    await loadSessions()
                }
            }
            .onChange(of: environment.lastGenerationFailure?.userMessage) { _, message in
                showGenerationFailureAlert = message != nil
            }
            .alert(
                "Can't Build Workout",
                isPresented: $showGenerationFailureAlert,
                presenting: environment.lastGenerationFailure
            ) { _ in
                Button("OK", role: .cancel) {
                    environment.lastGenerationFailure = nil
                }
            } message: { failure in
                Text(failure.userMessage)
            }
            .sheet(isPresented: $showSummary) {
                if let session = completedSession {
                    NavigationStack {
                        WorkoutCompletionView(session: session) {
                            showSummary = false
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showSummary = false }
                            }
                        }
                    }
                }
            }
        }
    }

    private func workoutCard(_ workout: GeneratedWorkout) -> some View {
        let completed = environment.isTodayWorkoutCompleted
        let isResuming = !completed && activeSession != nil

        return ForgeHeroCard(
            eyebrow: completed ? "Session" : (isResuming ? "In Progress" : "Active Session"),
            title: workout.title,
            badge: completed ? "Completed" : nil,
            durationMinutes: completed ? nil : workout.estimatedDurationMinutes,
            focusLine: isResuming
                ? resumeProgressLine
                : "\(workout.exercises.count) exercises · \(totalSets(workout)) working sets",
            completed: completed,
            titleAccessory: canToggleSplitFocus ? ForgeHeroTitleAccessory(
                systemImage: "arrow.up.arrow.down",
                accessibilityLabel: splitToggleAccessibilityLabel,
                action: { switchSplitFocus() }
            ) : nil,
            loadingSecondaryTitle: isRegenerating ? "Regenerate" : nil,
            primaryAction: completed
                ? ("View Summary", { showSummary = true })
                : (isResuming ? "Resume" : "Start", { startWorkout(workout) }),
            secondaryActions: completed
                ? [
                    ("Preview Plan", { router.navigate(to: .workoutPreview(workout)) }),
                    ("Restart Training", { restartWorkoutOnly() })
                  ]
                : [
                    ("Regenerate", { regenerateWorkout() }),
                    ("Preview Plan", { router.navigate(to: .workoutPreview(workout)) })
                ]
        )
        .id(workout.id)
        .scaleEffect(isRegenerating ? 0.97 : 1)
        .opacity(isRegenerating ? 0.88 : (completed ? 0.92 : 1))
        .blur(radius: isRegenerating ? 1.5 : 0)
        .animation(ForgeMotion.regenerate, value: isRegenerating)
        .overlay {
            if isRegenerating {
                TrainHeroRegeneratingOverlay(isSpinning: regenSpin)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .allowsHitTesting(!isRegenerating)
    }

    private var resumeProgressLine: String {
        guard let activeSession else {
            return ""
        }
        let logged = WorkoutSessionCalculator.completedSetCount(session: activeSession)
        let total = WorkoutSessionCalculator.totalPlannedSets(exercises: activeSession.exercises)
        return "\(logged) of \(total) sets logged · tap to resume"
    }

    private var historySection: some View {
        ForgeCard {
            Text("HISTORY")
                .font(ForgeTypography.caption)
                .tracking(2)
                .foregroundStyle(ForgeColors.accent)

            if completedSessions.isEmpty {
                Text("No completed workouts yet.")
                    .font(ForgeTypography.body)
                    .foregroundStyle(ForgeColors.muted)
            } else {
                ForEach(Array(completedSessions.enumerated()), id: \.element.id) { index, session in
                    NavigationLink(value: session.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .font(ForgeTypography.title)
                                .foregroundStyle(ForgeColors.foreground)
                            if let date = session.completedAt {
                                Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                                    .font(ForgeTypography.monoMetric)
                                    .foregroundStyle(ForgeColors.muted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    if index < completedSessions.count - 1 {
                        Rectangle()
                            .fill(ForgeColors.border)
                            .frame(height: 1)
                    }
                }
            }
        }
    }

    private var librarySection: some View {
        ForgeCard {
            ForgeSectionHeader(title: "Exercise Library", accent: ForgeColors.accent)
            ForgeButton(title: "Browse Exercises") { showLibrary = true }
        }
    }

    private func totalSets(_ workout: GeneratedWorkout) -> Int {
        workout.exercises.reduce(0) { $0 + $1.targetSets.count }
    }

    private var completedSessions: [WorkoutSession] {
        sessions
            .filter { $0.status == .completed }
            .sorted {
                ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
            }
            .prefix(5)
            .map { $0 }
    }

    private var trainHeaderSubtitle: String {
        if let workout = environment.todayWorkout {
            return "\(workout.title) ready · \(workout.exercises.count) exercises"
        }
        return "Generate today's session from the Today tab."
    }

    private var canToggleSplitFocus: Bool {
        guard environment.todayWorkout != nil, let profile = environment.userProfile else { return false }
        return TrainingSchedule.splitSequence(for: profile.preferredSplit).count > 1
    }

    private var splitToggleAccessibilityLabel: String {
        guard let profile = environment.userProfile,
              let current = environment.currentSplitFocus,
              let next = TrainingSchedule.nextSplitFocus(after: current, split: profile.preferredSplit) else {
            return "Switch training focus"
        }
        return "Switch to \(next.displayName.lowercased()) training"
    }

    private func startWorkout(_ workout: GeneratedWorkout) {
        Task {
            guard let session = await environment.resumeOrStartWorkout(from: workout) else { return }
            activeSession = session
            router.replace(with: .workoutSession(session))
        }
    }

    private func loadSessions() async {
        sessions = await environment.fetchWorkoutSessions()
    }

    private func loadActiveSession() async {
        activeSession = await environment.fetchActiveWorkoutSession()
    }

    private func loadCompletedSession() async {
        completedSession = await environment.fetchTodayCompletedSession()
    }

    private func regenerateWorkout() {
        guard !environment.isWorkoutGenerationInFlight else { return }
        performAnimatedWorkoutRefresh(.regenerate)
    }

    private func restartWorkoutOnly() {
        guard !environment.isWorkoutGenerationInFlight, !isRegenerating else { return }
        guard let profile = environment.userProfile else { return }

        Task { @MainActor in
            withAnimation(ForgeMotion.regenerate) {
                isRegenerating = true
                regenSpin = true
            }

            _ = await environment.restartTodayWorkout(profile: profile)

            await loadCompletedSession()
            await loadActiveSession()
            await loadSessions()

            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(ForgeMotion.regenerate) {
                isRegenerating = false
                regenSpin = false
            }
        }
    }

    private func switchSplitFocus() {
        guard canToggleSplitFocus, !environment.isWorkoutGenerationInFlight else { return }
        performAnimatedWorkoutRefresh(.switchSplit)
    }

    private enum WorkoutRefreshKind {
        case regenerate
        case switchSplit
    }

    private func performAnimatedWorkoutRefresh(_ kind: WorkoutRefreshKind) {
        guard !isRegenerating, !environment.isWorkoutGenerationInFlight else { return }
        Task { @MainActor in
            withAnimation(ForgeMotion.regenerate) {
                isRegenerating = true
                regenSpin = true
            }

            async let refreshResult = performWorkoutRefresh(kind)
            try? await Task.sleep(for: ForgeMotion.regenerateMinimum)

            _ = await refreshResult
            await loadCompletedSession()
            await loadActiveSession()
            await loadSessions()

            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(ForgeMotion.regenerate) {
                isRegenerating = false
                regenSpin = false
            }
        }
    }

    @MainActor
    private func performWorkoutRefresh(_ kind: WorkoutRefreshKind) async -> Bool {
        switch kind {
        case .regenerate:
            guard let profile = environment.userProfile else { return false }
            return await environment.regenerateTodayWorkout(profile: profile)
        case .switchSplit:
            return await environment.switchTodaySplitFocus()
        }
    }
}

private struct TrainHeroRegeneratingOverlay: View {
    let isSpinning: Bool

    var body: some View {
        ZStack {
            ForgeColors.surfaceInverse.opacity(0.82)

            VStack(spacing: 16) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: ForgeIcons.lg + 4, weight: .semibold))
                    .foregroundStyle(ForgeColors.accent)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(
                        isSpinning ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default,
                        value: isSpinning
                    )

                Text("Building new session...")
                    .font(ForgeTypography.caption)
                    .tracking(3)
                    .foregroundStyle(ForgeColors.surface.opacity(0.92))
            }
        }
    }
}

struct WorkoutHistoryDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession
    @State private var exerciseNameById: [String: String] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForgeScreenHeader(
                    title: session.title,
                    style: .compact,
                    eyebrow: "History",
                    subtitle: sessionDateLine,
                    leading: {
                        ForgeHeaderBackButton { dismiss() }
                    }
                )

                ForgeCard {
                    Text("OVERVIEW")
                        .font(ForgeTypography.caption)
                        .tracking(1.5)
                        .foregroundStyle(ForgeColors.muted)
                    Text("\(completedSets) of \(plannedSets) sets completed")
                        .font(ForgeTypography.heading)
                    Text("Calories ~\(estimatedCalories)")
                        .font(ForgeTypography.monoMetric)
                        .foregroundStyle(ForgeColors.muted)
                    Text("Volume \(Int(totalVolumeKg)) kg")
                        .font(ForgeTypography.monoMetric)
                        .foregroundStyle(ForgeColors.muted)
                    if let durationMinutes {
                        Text("Duration \(durationMinutes)m")
                            .font(ForgeTypography.monoMetric)
                            .foregroundStyle(ForgeColors.muted)
                    }
                }

                ForgeCard {
                    Text("EXERCISES")
                        .font(ForgeTypography.caption)
                        .tracking(1.5)
                        .foregroundStyle(ForgeColors.muted)
                    ForEach(Array(sortedExercises.enumerated()), id: \.element.id) { index, exercise in
                        VStack(alignment: .leading, spacing: 8) {
                            NavigationLink(value: exercise.exerciseId) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exerciseDisplayName(for: exercise.exerciseId))
                                        .font(ForgeTypography.body)
                                        .foregroundStyle(ForgeColors.foreground)
                                    Text("\(exercise.completedSets.count) / \(exercise.plannedSets.count) sets")
                                        .font(ForgeTypography.monoMetric)
                                        .foregroundStyle(ForgeColors.muted)
                                }
                            }
                            .buttonStyle(.plain)

                            if exercise.completedSets.isEmpty {
                                Text("No sets logged")
                                    .font(ForgeTypography.caption)
                                    .foregroundStyle(ForgeColors.muted)
                            } else {
                                ForEach(sortedCompletedSets(for: exercise)) { set in
                                    Text(setLine(for: set))
                                        .font(ForgeTypography.caption)
                                        .foregroundStyle(ForgeColors.muted)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        if index < sortedExercises.count - 1 {
                            Rectangle()
                                .fill(ForgeColors.border)
                                .frame(height: 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(ForgeColors.background)
        .forgeFloatingTabBarClearance()
        .forgeScreenNavigationHidden()
        .navigationDestination(for: String.self) { exerciseId in
            ExerciseDetailView(exerciseId: exerciseId)
        }
        .task { await loadExerciseNames() }
    }

    private var completedSets: Int {
        session.exercises.reduce(0) { $0 + $1.completedSets.count }
    }

    private var plannedSets: Int {
        session.exercises.reduce(0) { $0 + $1.plannedSets.count }
    }

    private var durationMinutes: Int? {
        guard let startedAt = session.startedAt, let completedAt = session.completedAt else { return nil }
        return max(1, Int(completedAt.timeIntervalSince(startedAt) / 60))
    }

    private var estimatedCalories: Int {
        WorkoutSessionCalculator.estimatedCaloriesBurned(
            elapsedSeconds: elapsedSeconds,
            bodyWeightKg: environment.userProfile?.weightKg ?? 80
        )
    }

    private var elapsedSeconds: Int {
        guard let startedAt = session.startedAt, let completedAt = session.completedAt else {
            return session.estimatedDurationMinutes * 60
        }
        return max(0, Int(completedAt.timeIntervalSince(startedAt)))
    }

    private var totalVolumeKg: Double {
        WorkoutSessionCalculator.completedVolumeKg(session: session)
    }

    private var sortedExercises: [WorkoutExercise] {
        session.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    private func sortedCompletedSets(for exercise: WorkoutExercise) -> [CompletedSet] {
        exercise.completedSets.sorted { $0.setIndex < $1.setIndex }
    }

    private func exerciseDisplayName(for id: String) -> String {
        exerciseNameById[id] ?? id.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func setLine(for set: CompletedSet) -> String {
        let weightText: String
        if let weight = set.weightKg {
            weightText = "\(Int(weight.rounded()))kg"
        } else {
            weightText = "Bodyweight"
        }
        return "Set \(set.setIndex + 1): \(weightText) x \(set.reps)"
    }

    private func loadExerciseNames() async {
        let exercises = await environment.fetchAllExercises()
        exerciseNameById = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) })
    }

    private var sessionDateLine: String {
        if let completedAt = session.completedAt {
            return completedAt.formatted(.dateTime.month(.abbreviated).day().year())
        }
        return "Completed workout"
    }
}

struct WorkoutPreviewView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var workout: GeneratedWorkout
    @State private var exercises: [String: Exercise] = [:]
    @State private var swapResolver: ExerciseSwapResolver?
    @State private var swapTarget: PlannedExercise?
    @State private var showSwapSheet = false
    @State private var hasActiveSession = false

    init(workout: GeneratedWorkout) {
        _workout = State(initialValue: workout)
    }

    var body: some View {
        VStack(spacing: 0) {
            ForgeScreenHeader(
                title: workout.title,
                style: .compact,
                eyebrow: "Preview",
                subtitle: workout.focus.map(\.displayName).joined(separator: " · "),
                leading: {
                    ForgeHeaderBackButton { router.dismissRoute() }
                }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    previewHeader
                    exerciseTimeline
                }
            }

            VStack(spacing: 0) {
                Divider()
                ForgeButton(title: hasActiveSession ? "Resume Workout" : "Start Workout", style: .accent) { startSession() }
                    .padding()
            }
            .background(ForgeColors.surface)
        }
        .background(ForgeColors.background)
        .forgeScreenNavigationHidden()
        .navigationDestination(for: String.self) { exerciseId in
            ExerciseDetailView(exerciseId: exerciseId)
        }
        .task {
            await loadExercises()
            hasActiveSession = await environment.fetchActiveWorkoutSession() != nil
            syncWorkoutFromEnvironment()
        }
        .onChange(of: environment.todayWorkout?.id) { _, _ in
            syncWorkoutFromEnvironment()
        }
        .sheet(isPresented: $showSwapSheet) {
            if let target = swapTarget {
                SwapExerciseSheet(
                    currentExerciseId: target.exerciseId,
                    substitutionGroup: swapResolver?.substitutionGroup(for: target.exerciseId),
                    substitutes: swapResolver?.swapCandidates(
                        for: target.exerciseId,
                        workoutExerciseIds: Set(workout.exercises.map(\.exerciseId))
                    ) ?? []
                ) { substitute in
                    swapExercise(target, to: substitute)
                }
            }
        }
    }

    private var previewHeader: some View {
        let weightKg = environment.userProfile?.weightKg ?? 80
        let estimatedCalories = WorkoutSessionCalculator.estimatedCaloriesBurned(
            elapsedSeconds: workout.estimatedDurationMinutes * 60,
            bodyWeightKg: weightKg
        )

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 0) {
                previewMetric(label: "Exercises", value: "\(workout.exercises.count)")
                previewMetricDivider
                previewMetric(label: "Duration", value: "\(workout.estimatedDurationMinutes)m")
                previewMetricDivider
                previewMetric(label: "Calories", value: "~\(estimatedCalories)")
            }
            .padding(.vertical, 4)

            HStack(spacing: 8) {
                ForgePill(label: "\(totalSets) sets")
                ForgePill(label: "\(muscleCount) muscles")
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func previewMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(ForgeTypography.caption)
                .tracking(1.5)
                .foregroundStyle(ForgeColors.muted)
            Text(value)
                .font(ForgeTypography.monoMetric)
                .foregroundStyle(ForgeColors.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var previewMetricDivider: some View {
        Rectangle()
            .fill(ForgeColors.border)
            .frame(width: 1, height: 36)
    }

    private var exerciseTimeline: some View {
        let sorted = workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, planned in
                HStack(alignment: .top, spacing: 12) {
                    NavigationLink(value: planned.exerciseId) {
                        WorkoutExerciseTimelineRow(
                            planned: planned,
                            exercise: exercises[planned.exerciseId],
                            isFocus: index == 0,
                            isLast: index == sorted.count - 1
                        )
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Button("Swap") {
                            swapTarget = planned
                            showSwapSheet = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(ForgeColors.muted)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 24)
    }

    private var muscleCount: Int {
        Set(workout.exercises.flatMap { exercises[$0.exerciseId]?.primaryMuscles ?? [] }).count
    }

    private var totalSets: Int {
        workout.exercises.reduce(0) { $0 + $1.targetSets.count }
    }

    private func loadExercises() async {
        let used = Set(workout.exercises.map(\.exerciseId))
        guard let resolver = await environment.loadExerciseSwapResolver(usedExerciseIds: used) else { return }
        swapResolver = resolver
        exercises = resolver.exerciseMap
    }

    private func swapExercise(_ planned: PlannedExercise, to substitute: Exercise) {
        guard let idx = workout.exercises.firstIndex(where: { $0.id == planned.id }) else { return }
        workout.exercises[idx] = PlannedExercise(
            id: planned.id,
            exerciseId: substitute.id,
            orderIndex: planned.orderIndex,
            targetSets: planned.targetSets,
            restSeconds: planned.restSeconds,
            intensity: planned.intensity,
            reason: "Swapped from \(planned.exerciseId) to \(substitute.name)."
        )
        environment.todayWorkout = workout
        Task { try? await environment.saveTodayWorkout(workout) }
    }

    private func startSession() {
        Task {
            guard let session = await environment.resumeOrStartWorkout(from: workout) else { return }
            router.replace(with: .workoutSession(session))
        }
    }

    private func syncWorkoutFromEnvironment() {
        guard let latest = environment.todayWorkout, latest.id != workout.id else { return }
        workout = latest
    }
}
