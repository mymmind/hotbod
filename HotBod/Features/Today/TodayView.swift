import SwiftUI

struct TodayView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var proteinToday: Double = 0
    @State private var proteinStreak = 0
    @State private var showSettings = false
    @State private var showCoach = false
    @State private var completedSession: WorkoutSession?
    @State private var activeSession: WorkoutSession?
    @State private var showSummary = false
    @State private var exerciseCatalog: [String: Exercise] = [:]
    @State private var isRegenerating = false
    @State private var regenSpin = false
    @State private var contentAppeared = false
    @State private var showRecoveryDetails = false
    @State private var showGenerationFailureAlert = false

    private var todayContentMode: String {
        if environment.isRestDay { return "rest" }
        if environment.todayWorkout != nil {
            return environment.isTodayWorkoutCompleted ? "completed" : "workout"
        }
        return "empty"
    }

    private var proteinGoal: Double {
        environment.userProfile?.proteinGoalGrams ?? 145
    }

    private var averageReadiness: Double {
        let states = environment.recoveryStates
        guard !states.isEmpty else { return 0 }
        return states.map(\.recoveryPercentage).reduce(0, +) / Double(states.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForgeScreenHeader(
                        title: "Today",
                        eyebrow: timeGreeting,
                        subtitle: dailyBriefSubtitle,
                        meta: Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                        trailing: { settingsButton }
                    )
                    primaryTodayContent
                }
            }
            .background(ForgeColors.background)
            .forgeFloatingTabBarClearance()
            .forgeScreenNavigationHidden()
            .sheet(isPresented: $showSettings) { SettingsView(presentation: .sheet) }
            .sheet(isPresented: $showRecoveryDetails) {
                RecoveryDetailSheet(
                    averageReadiness: averageReadiness,
                    states: environment.recoveryStates
                )
            }
            .navigationDestination(isPresented: $showCoach) {
                CoachView(presentation: .navigationPush)
            }
            .task {
                await loadProtein()
                await loadExerciseCatalog()
                await environment.refreshHealthReadiness()
                await loadCompletedSession()
                await loadActiveSession()
            }
            .onAppear {
                contentAppeared = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    contentAppeared = true
                }
            }
            .onChange(of: todayContentMode) { _, _ in
                contentAppeared = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    contentAppeared = true
                }
            }
            .onChange(of: environment.todayWorkout?.id) { _, _ in
                Task { await loadExerciseCatalog() }
            }
            .onChange(of: environment.isTodayWorkoutCompleted) { _, _ in
                Task {
                    await loadCompletedSession()
                    await loadActiveSession()
                }
            }
            .onChange(of: router.route) { _, newRoute in
                if case .main = newRoute {
                    Task { await loadActiveSession() }
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

    @ViewBuilder
    private var primaryTodayContent: some View {
        if environment.isRestDay {
            editorialLayout(hero: { restDayHero })
        } else if let workout = environment.todayWorkout {
            editorialLayout(
                workout: workout,
                hero: {
                    workoutHero(workout, completed: environment.isTodayWorkoutCompleted, session: completedSession)
                },
                secondary: {
                    if !environment.isTodayWorkoutCompleted {
                        secondarySections(workout: workout)
                    }
                }
            )
        } else {
            VStack(spacing: 16) {
                EmptyStateView(
                    title: "No workout yet",
                    message: "Generate today's \(environment.currentSplitFocus?.displayName ?? "training") session."
                ) {
                    if let profile = environment.userProfile {
                        Task { await environment.regenerateTodayWorkout(profile: profile) }
                    }
                }
            }
            .padding()
        }
    }

    private func editorialLayout<Hero: View, Secondary: View>(
        workout: GeneratedWorkout? = nil,
        @ViewBuilder hero: () -> Hero,
        @ViewBuilder secondary: () -> Secondary = { EmptyView() }
    ) -> some View {
        VStack(spacing: 0) {
            hero()

            VStack(spacing: 20) {
                if let workout, !environment.isTodayWorkoutCompleted {
                    TodayExerciseStrip(
                        workout: workout,
                        exercises: exerciseCatalog,
                        onPreview: { router.navigate(to: .workoutPreview(workout)) }
                    )
                    .forgeStaggeredAppear(index: 0, isVisible: contentAppeared)
                }

                bentoRow
                    .forgeStaggeredAppear(index: 1, isVisible: contentAppeared)

                sorenessStrip
                    .forgeStaggeredAppear(index: 2, isVisible: contentAppeared)

                secondary()
                    .forgeStaggeredAppear(index: 3, isVisible: contentAppeared)

                progressFooter
                    .forgeStaggeredAppear(index: 4, isVisible: contentAppeared)
            }
            .padding(.horizontal, ForgeSpacing.s5)
            .padding(.top, ForgeSpacing.s5)
            .padding(.bottom, ForgeSpacing.s6)
            .id("bento-\(todayContentMode)")
        }
    }

    private var settingsButton: some View {
        Button { showSettings = true } label: {
            Image(systemName: "gearshape")
                .font(.body.weight(.semibold))
                .foregroundStyle(ForgeColors.accent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(ForgeColors.surface))
                .forgeElevation(.tabBar)
        }
        .buttonStyle(.plain)
        .frame(width: ForgeTarget.min, height: ForgeTarget.min)
        .contentShape(Rectangle())
        .accessibilityLabel("Settings")
    }

    // MARK: - Hero

    private var restDayHero: some View {
        ForgeHeroCard(
            eyebrow: "Rest Day",
            title: "Recovery",
            footerLine: restDayFooterLine,
            inverted: true,
            ambientGlow: true,
            accent: ForgeColors.accentGreen
        )
    }

    private var restDayFooterLine: String? {
        var parts: [String] = []
        if let nextDay = environment.userProfile.flatMap({ TrainingSchedule.nextTrainingDayLabel(profile: $0) }) {
            parts.append("Next session: \(nextDay)")
        }
        if let focus = environment.userProfile.flatMap({
            TrainingSchedule.currentSplitFocus(state: environment.programState, split: $0.preferredSplit)
        }) {
            parts.append("Up next: \(focus.displayName)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func workoutHero(_ workout: GeneratedWorkout, completed: Bool, session: WorkoutSession?) -> some View {
        ForgeHeroCard(
            eyebrow: completed ? "Session" : (environment.currentSplitFocus?.displayName ?? "Today"),
            title: workout.title,
            badge: completed ? "Completed" : nil,
            durationMinutes: completed ? nil : workout.estimatedDurationMinutes,
            focusLine: workout.focus.map(\.displayName).joined(separator: " · "),
            exerciseLine: completed ? exerciseNameLine(for: workout) : nil,
            safetyNotes: completed ? [] : workout.safetyNotes,
            completed: completed,
            completionMetrics: completed ? completionMetricData(session) : [],
            footerLine: completed ? completedFooterLine : nil,
            inverted: !completed,
            ambientGlow: !completed,
            statPills: completed ? [] : workoutStatPills(for: workout, activeSession: activeSession),
            titleAccessory: canToggleSplitFocus ? ForgeHeroTitleAccessory(
                systemImage: "arrow.up.arrow.down",
                accessibilityLabel: splitToggleAccessibilityLabel,
                action: { switchSplitFocus() }
            ) : nil,
            loadingSecondaryTitle: isRegenerating ? "Regenerate" : nil,
            primaryAction: completed
                ? ("View Summary", { showSummary = true })
                : (activeSession != nil ? "Resume Workout" : "Start Workout", { startWorkout(workout) }),
            secondaryActions: completed
                ? [
                    ("Preview Plan", { router.navigate(to: .workoutPreview(workout)) }),
                    ("Restart Training", { restartWorkoutOnly() })
                  ]
                : [
                    ("Regenerate", { regenerateWorkout() }),
                    ("Preview", { router.navigate(to: .workoutPreview(workout)) })
                ]
        )
        .id(workout.id)
        .scaleEffect(isRegenerating ? 0.97 : 1)
        .opacity(isRegenerating ? 0.88 : (completed ? 0.92 : 1))
        .blur(radius: isRegenerating ? 1.5 : 0)
        .animation(ForgeMotion.regenerate, value: isRegenerating)
        .overlay {
            if isRegenerating {
                ForgeHeroRegeneratingOverlay(isSpinning: regenSpin)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .allowsHitTesting(!isRegenerating)
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

    private func switchSplitFocus() {
        guard !environment.isWorkoutGenerationInFlight else { return }
        performAnimatedWorkoutRefresh(.switchSplit)
    }

    private func workoutStatPills(for workout: GeneratedWorkout, activeSession: WorkoutSession? = nil) -> [String] {
        let weightKg = environment.userProfile?.weightKg ?? 80
        let estimatedCalories = WorkoutSessionCalculator.estimatedCaloriesBurned(
            elapsedSeconds: workout.estimatedDurationMinutes * 60,
            bodyWeightKg: weightKg
        )
        var pills = [
            "\(workout.exercises.count) exercises",
            "\(totalWorkingSets(for: workout)) sets",
            "~\(estimatedCalories) kcal"
        ]
        if let activeSession {
            let logged = WorkoutSessionCalculator.completedSetCount(session: activeSession)
            let total = WorkoutSessionCalculator.totalPlannedSets(exercises: activeSession.exercises)
            pills.insert("\(logged)/\(total) logged", at: 0)
        }
        return pills
    }

    private func totalWorkingSets(for workout: GeneratedWorkout) -> Int {
        workout.exercises.reduce(0) { $0 + $1.targetSets.count }
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
            await loadExerciseCatalog()

            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(ForgeMotion.regenerate) {
                isRegenerating = false
                regenSpin = false
            }
        }
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

            if await refreshResult {
                await loadExerciseCatalog()
            }
            await loadCompletedSession()
            await loadActiveSession()

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

    private var completedFooterLine: String? {
        environment.userProfile.flatMap { TrainingSchedule.nextTrainingDayLabel(profile: $0) }
            .map { "Next session: \($0)" }
    }

    private func completionMetricData(_ session: WorkoutSession?) -> [(label: String, value: String)] {
        guard let session else { return [] }
        let volume = session.exercises.flatMap(\.completedSets).reduce(0.0) { $0 + ($1.weightKg ?? 0) * Double($1.reps) }
        let sets = session.exercises.flatMap(\.completedSets).count
        let duration: Int = {
            guard let start = session.startedAt, let end = session.completedAt else {
                return session.estimatedDurationMinutes
            }
            return Int(end.timeIntervalSince(start) / 60)
        }()
        return [
            (label: "Volume", value: "\(Int(volume))kg"),
            (label: "Sets", value: "\(sets)"),
            (label: "Duration", value: "\(duration)m")
        ]
    }

    // MARK: - Bento

    private var bentoRow: some View {
        HStack(alignment: .top, spacing: 12) {
            TodayMetricTile(
                label: "Overall",
                value: "\(Int(averageReadiness))%",
                progress: averageReadiness / 100,
                accent: ForgeColors.readiness(averageReadiness),
                subtitle: overallReadinessSubtitle,
                iconName: "bolt.heart.fill",
                action: { showRecoveryDetails = true }
            )

            TodayMetricTile(
                label: "Protein",
                value: "\(Int(proteinToday))g",
                progress: proteinGoal > 0 ? proteinToday / proteinGoal : 0,
                accent: ForgeColors.accentBlue,
                subtitle: "\(Int(max(0, proteinGoal - proteinToday)))g left",
                iconName: "fork.knife",
                action: { router.selectedTab = .protein }
            )
        }
    }

    private var sorenessStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Readiness Check")
                    .font(ForgeTypography.caption)
                    .tracking(2)
                    .foregroundStyle(ForgeColors.muted)
                Spacer()
                if let hint = environment.healthReadiness.recoveryHint {
                    Text(hint)
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.muted)
                        .lineLimit(1)
                }
            }

            Text("How sore are you?")
                .font(ForgeTypography.heading)

            HStack(spacing: 6) {
                ForEach(SorenessLevel.allCases) { level in
                    SelectableChip(title: level.id.capitalized, isSelected: environment.sorenessLevel == level) {
                        Task { await environment.setSoreness(level) }
                    }
                }
            }

            if let sleepHours = environment.healthReadiness.sleepHoursLastNight {
                HStack(spacing: 8) {
                    Image(systemName: "moon.fill")
                        .foregroundStyle(ForgeColors.accentBlue)
                    Text(String(format: "Sleep last night: %.1f h", sleepHours))
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.muted)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(ForgeColors.surface)
                .shadow(color: .black.opacity(0.05), radius: 14, y: 6)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(ForgeColors.border, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func secondarySections(workout: GeneratedWorkout) -> some View {
        if let validation = environment.lastValidation, !validation.warnings.isEmpty {
            TodayDisclosureSection(title: "Safety Notes") {
                ForEach(validation.warnings, id: \.self) { warning in
                    Text("· \(warning)")
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.muted)
                }
            }
        }

        if let validation = environment.lastValidation, !validation.suggestions.isEmpty {
            TodayDisclosureSection(title: "Suggestions") {
                ForEach(validation.suggestions, id: \.self) { suggestion in
                    Text("· \(suggestion)")
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.muted)
                }
            }
        }

        TodayDisclosureSection(title: "Why This Workout?") {
            Text(workout.rationale)
                .font(ForgeTypography.body)
            ForgeButton(title: "Ask Coach", style: .secondary) { showCoach = true }
        }
    }

    private var progressFooter: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                progressStatCard(
                    label: "Bodyweight",
                    value: "\(Int(environment.userProfile?.weightKg ?? 0)) kg",
                    icon: "scalemass.fill"
                )
                progressStatCard(
                    label: "Protein Streak",
                    value: "\(proteinStreak)d",
                    icon: "flame.fill",
                    accent: ForgeColors.accentBlue
                )
            }

            ForgeButton(title: "View Progress", style: .secondary) {
                router.selectedTab = .progress
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(ForgeColors.surface)
                .shadow(color: .black.opacity(0.05), radius: 14, y: 6)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(ForgeColors.border, lineWidth: 1)
        }
    }

    private func progressStatCard(label: String, value: String, icon: String, accent: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent ?? ForgeColors.muted)
                Text(label.uppercased())
                    .font(ForgeTypography.caption)
                    .tracking(1.5)
                    .foregroundStyle(ForgeColors.muted)
            }
            Text(value)
                .font(ForgeTypography.monoMetric)
                .foregroundStyle(accent ?? ForgeColors.foreground)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(ForgeColors.foreground.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func exerciseNameLine(for workout: GeneratedWorkout) -> String? {
        let names = workout.exercises
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { exerciseCatalog[$0.exerciseId]?.name ?? $0.exerciseId }
        guard !names.isEmpty else { return nil }
        return names.joined(separator: ", ")
    }

    private func loadExerciseCatalog() async {
        let all = await environment.fetchAllExercises()
        exerciseCatalog = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }

    private var readinessLabel: String {
        averageReadiness >= 70 ? "Good" : averageReadiness >= 50 ? "Moderate" : "Low"
    }

    private var overallReadinessSubtitle: String {
        let remaining = Int(max(0, 100 - averageReadiness))
        return remaining > 0 ? "\(remaining)% to full" : readinessLabel
    }

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    private var dailyBriefSubtitle: String {
        if environment.isRestDay {
            return "Recovery day — let your muscles rebuild."
        }
        if environment.isTodayWorkoutCompleted {
            return "Session complete. Stay on top of protein tonight."
        }
        if let workout = environment.todayWorkout {
            return "\(workout.exercises.count) exercises lined up · ~\(workout.estimatedDurationMinutes) min"
        }
        return "Your plan is loading."
    }

    private func startWorkout(_ workout: GeneratedWorkout) {
        Task {
            guard let session = await environment.resumeOrStartWorkout(from: workout) else { return }
            activeSession = session
            router.replace(with: .workoutSession(session))
        }
    }

    private func loadProtein() async {
        let summary = await environment.proteinSummary()
        proteinToday = summary.todayGrams
        proteinStreak = summary.streakDays
    }

    private func loadCompletedSession() async {
        if environment.isTodayWorkoutCompleted {
            completedSession = await environment.fetchTodayCompletedSession()
        } else {
            completedSession = nil
        }
    }

    private func loadActiveSession() async {
        if environment.isTodayWorkoutCompleted {
            activeSession = nil
        } else {
            activeSession = await environment.fetchActiveWorkoutSession()
        }
    }
}

private struct RecoveryDetailSheet: View {
    let averageReadiness: Double
    let states: [MuscleRecoveryState]
    @Environment(\.dismiss) private var dismiss

    private var sortedStates: [MuscleRecoveryState] {
        states.sorted { $0.recoveryPercentage > $1.recoveryPercentage }
    }

    private var restedMuscles: [MuscleRecoveryState] {
        sortedStates.filter { $0.recoveryPercentage >= 75 }
    }

    private var recoveringMuscles: [MuscleRecoveryState] {
        sortedStates.filter { $0.recoveryPercentage < 75 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.s4) {
                    summaryCard

                    if restedMuscles.isEmpty {
                        Text("No muscle groups are fully rested yet.")
                            .font(ForgeTypography.body)
                            .foregroundStyle(ForgeColors.muted)
                    } else {
                        detailSection(title: "Rested Muscles", states: restedMuscles)
                    }

                    if !recoveringMuscles.isEmpty {
                        detailSection(title: "Still Recovering", states: recoveringMuscles)
                    }
                }
                .padding(ForgeSpacing.s5)
            }
            .background(ForgeColors.background)
            .navigationTitle("Recovery Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s2) {
            Text("Overall Readiness")
                .font(ForgeTypography.caption)
                .tracking(ForgeTracking.eyebrow)
                .foregroundStyle(ForgeColors.muted)
            Text("\(Int(averageReadiness))%")
                .font(ForgeTypography.metric)
                .foregroundStyle(ForgeColors.readiness(averageReadiness))
            ForgeProgressBar(progress: averageReadiness / 100, fill: ForgeColors.readiness(averageReadiness))
        }
        .padding(ForgeSpacing.s4)
        .background(ForgeColors.surface)
        .overlay {
            RoundedRectangle(cornerRadius: ForgeRadius.soft)
                .stroke(ForgeColors.border, lineWidth: ForgeBorder.hairline)
        }
        .clipShape(RoundedRectangle(cornerRadius: ForgeRadius.soft))
    }

    private func detailSection(title: String, states: [MuscleRecoveryState]) -> some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
            Text(title)
                .font(ForgeTypography.heading)

            ForEach(states) { state in
                HStack(spacing: ForgeSpacing.s3) {
                    Text(state.muscleGroup.displayName)
                        .font(ForgeTypography.body)
                    Spacer()
                    Text("\(Int(state.recoveryPercentage))%")
                        .font(ForgeTypography.monoMetric)
                        .foregroundStyle(ForgeColors.readiness(state.recoveryPercentage))
                }
                ForgeProgressBar(
                    progress: state.recoveryPercentage / 100,
                    fill: ForgeColors.readiness(state.recoveryPercentage)
                )
            }
        }
        .padding(ForgeSpacing.s4)
        .background(ForgeColors.surface)
        .overlay {
            RoundedRectangle(cornerRadius: ForgeRadius.soft)
                .stroke(ForgeColors.border, lineWidth: ForgeBorder.hairline)
        }
        .clipShape(RoundedRectangle(cornerRadius: ForgeRadius.soft))
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Text(title).font(ForgeTypography.heading)
            Text(message).foregroundStyle(ForgeColors.muted)
            if let action {
                ForgeButton(title: "Generate Workout", action: action)
            }
        }
        .padding(32)
    }
}

#Preview("Today — Workout") {
    TodayView()
        .environment(AppEnvironment())
        .environment(AppRouter())
}

private struct ForgeHeroRegeneratingOverlay: View {
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
