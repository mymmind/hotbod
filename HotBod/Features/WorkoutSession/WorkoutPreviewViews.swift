import SwiftUI

// MARK: - Sheet routing

private enum WorkoutPreviewSheet: Identifiable {
    case detail(PlannedExercise)
    case swap(PlannedExercise)

    var id: String {
        switch self {
        case .detail(let planned): "detail-\(planned.id)"
        case .swap(let planned): "swap-\(planned.id)"
        }
    }
}

// MARK: - Main preview

struct WorkoutPreviewView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var workout: GeneratedWorkout
    @State private var orderedExercises: [PlannedExercise] = []
    @State private var exercises: [String: Exercise] = [:]
    @State private var exerciseStatsById: [String: UserExerciseStats] = [:]
    @State private var swapResolver: ExerciseSwapResolver?
    @State private var activeSheet: WorkoutPreviewSheet?
    @State private var isReordering = false
    @State private var hasActiveSession = false
    @State private var showAddExercise = false
    @State private var libraryExercises: [Exercise] = []
    @State private var hasLocalPlanEdits = false

    private let contentPadding = ForgeSpacing.s5

    init(workout: GeneratedWorkout) {
        _workout = State(initialValue: workout)
        _orderedExercises = State(initialValue: WorkoutPlanEditor.sortedExercises(workout.exercises))
    }

    private var bodyWeightKg: Double {
        environment.userProfile?.weightKg ?? 80
    }

    private var experience: ExperienceLevel {
        environment.userProfile?.experienceLevel ?? .intermediate
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
                },
                trailing: {
                    HStack(spacing: ForgeSpacing.s3) {
                        Button("Add") { showAddExercise = true }
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.accent)
                            .accessibilityIdentifier("preview.addExercise")
                        Button(isReordering ? "Done" : "Reorder") {
                            withAnimation(ForgeMotion.quick) {
                                isReordering.toggle()
                            }
                        }
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.accent)
                        .accessibilityIdentifier("preview.reorderToggle")
                    }
                }
            )

            Group {
                if isReordering {
                    reorderList
                } else {
                    browseScroll
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomBar
        }
        .background(ForgeColors.background)
        .forgeScreenNavigationHidden()
        .task {
            await loadExercises()
            hasActiveSession = await environment.fetchActiveWorkoutSession() != nil
            syncWorkoutFromEnvironment()
        }
        .onChange(of: environment.todayWorkout?.id) { _, _ in
            syncWorkoutFromEnvironment()
        }
        .sheet(isPresented: $showAddExercise) {
            AddExerciseSheet(
                exercises: libraryExercises,
                usedExerciseIds: Set(orderedExercises.map(\.exerciseId))
            ) { selected in
                appendExercise(selected)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .detail(let planned):
                WorkoutPreviewExerciseDetailSheet(
                    planned: planned,
                    exercise: exercises[planned.exerciseId],
                    isFocus: planned.id == orderedExercises.first?.id,
                    onSwap: { activeSheet = .swap(planned) }
                )
            case .swap(let target):
                SwapExerciseSheet(
                    currentExerciseId: target.exerciseId,
                    substitutionGroup: swapResolver?.substitutionGroup(for: target.exerciseId),
                    substitutes: swapCandidates(for: target.exerciseId)
                ) { substitute in
                    swapExercise(target, to: substitute)
                    activeSheet = nil
                }
            }
        }
    }

    // MARK: - Browse mode

    private var browseScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ForgeSpacing.s5) {
                metricsBlock

                if !workout.rationale.isEmpty {
                    rationaleBlock
                }

                if !workout.selectionRationale.isEmpty {
                    selectionRationaleBlock
                }

                Text("Tap an exercise for sets and load. Use ↻ to swap.")
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: ForgeSpacing.s3) {
                    ForEach(Array(orderedExercises.enumerated()), id: \.element.id) { index, planned in
                        WorkoutPreviewExerciseCard(
                            planned: planned,
                            exercise: exercises[planned.exerciseId],
                            isFocus: index == 0,
                            onOpen: { activeSheet = .detail(planned) },
                            onSwap: { activeSheet = .swap(planned) }
                        )
                    }
                }
            }
            .padding(.horizontal, contentPadding)
            .padding(.top, ForgeSpacing.s2)
            .padding(.bottom, ForgeSpacing.s6)
        }
    }

    // MARK: - Reorder mode

    private var reorderList: some View {
        List {
            ForEach(orderedExercises) { planned in
                HStack(spacing: ForgeSpacing.s3) {
                    ExerciseThumbnailView(
                        exerciseId: planned.exerciseId,
                        primaryMuscle: exercises[planned.exerciseId]?.primaryMuscles.first?.displayName
                    )
                    .frame(width: 48, height: 48)

                    Text(exercises[planned.exerciseId]?.name ?? planned.exerciseId)
                        .font(ForgeTypography.heading)
                        .foregroundStyle(ForgeColors.foreground)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .listRowInsets(EdgeInsets(
                    top: ForgeSpacing.s2,
                    leading: contentPadding,
                    bottom: ForgeSpacing.s2,
                    trailing: contentPadding
                ))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onMove(perform: moveExercises)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Header blocks

    private var metricsBlock: some View {
        let estimatedCalories = WorkoutSessionCalculator.estimatedCaloriesBurned(
            elapsedSeconds: workout.estimatedDurationMinutes * 60,
            bodyWeightKg: bodyWeightKg
        )

        return VStack(alignment: .leading, spacing: ForgeSpacing.s4) {
            HStack(spacing: 0) {
                previewMetric(label: "Exercises", value: "\(workout.exercises.count)")
                previewMetricDivider
                previewMetric(label: "Duration", value: "\(workout.estimatedDurationMinutes)m")
                previewMetricDivider
                previewMetric(label: "Calories", value: "~\(estimatedCalories)")
            }

            HStack(spacing: ForgeSpacing.s2) {
                ForgePill(label: "\(totalSets) sets")
                ForgePill(label: "\(muscleCount) muscles")
            }
        }
    }

    private var rationaleBlock: some View {
        Text(workout.rationale)
            .font(ForgeTypography.body)
            .foregroundStyle(ForgeColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectionRationaleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHY THESE EXERCISES")
                .font(ForgeTypography.caption)
                .tracking(1.5)
                .foregroundStyle(ForgeColors.muted)
            ForEach(workout.selectionRationale, id: \.self) { line in
                Text("· \(line)")
                    .font(ForgeTypography.body)
                    .foregroundStyle(ForgeColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            ForgeButton(
                title: hasActiveSession ? "Resume Workout" : "Start Workout",
                style: .accent,
                accessibilityIdentifier: "preview.startWorkout"
            ) {
                startSession()
            }
            .padding(contentPadding)
        }
        .background(ForgeColors.surface)
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
            .padding(.horizontal, ForgeSpacing.s3)
    }

    private var muscleCount: Int {
        Set(workout.exercises.flatMap { exercises[$0.exerciseId]?.primaryMuscles ?? [] }).count
    }

    private var totalSets: Int {
        workout.exercises.reduce(0) { $0 + $1.targetSets.count }
    }

    // MARK: - Data

    private func swapCandidates(for exerciseId: String) -> [Exercise] {
        swapResolver?.swapCandidates(
            for: exerciseId,
            workoutExerciseIds: Set(workout.exercises.map(\.exerciseId))
        ) ?? []
    }

    private func loadExercises() async {
        let used = Set(workout.exercises.map(\.exerciseId))
        guard let resolver = await environment.loadExerciseSwapResolver(usedExerciseIds: used) else { return }
        swapResolver = resolver
        exercises = resolver.exerciseMap
        libraryExercises = resolver.allExercises
        let stats = await environment.fetchExerciseStats()
        exerciseStatsById = Dictionary(uniqueKeysWithValues: stats.map { ($0.exerciseId, $0) })
    }

    private func appendExercise(_ exercise: Exercise) {
        let planned = SessionExercisePlanner.makePlannedExercise(
            exercise: exercise,
            orderIndex: orderedExercises.count,
            experience: experience,
            goal: environment.userProfile?.goal ?? .buildMuscle,
            bodyWeightKg: bodyWeightKg,
            stats: exerciseStatsById[exercise.id],
            weightCeilings: environment.userProfile?.maxAvailableWeightKg ?? [:]
        )
        orderedExercises.append(planned)
        workout.exercises = orderedExercises
        exercises[exercise.id] = exercise
        persistWorkout()
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        orderedExercises = WorkoutPlanEditor.reordered(orderedExercises, from: source, to: destination)
        workout.exercises = orderedExercises
        persistWorkout()
    }

    private func swapExercise(_ planned: PlannedExercise, to substitute: Exercise) {
        guard let idx = orderedExercises.firstIndex(where: { $0.id == planned.id }) else { return }
        let replannedSets = ExerciseSwapReplanner.replannedSets(
            preservingStructureFrom: planned.targetSets,
            for: substitute,
            stats: exerciseStatsById[substitute.id],
            bodyweightKg: bodyWeightKg,
            experience: experience,
            weightCeilings: environment.userProfile?.maxAvailableWeightKg ?? [:]
        )
        orderedExercises[idx] = PlannedExercise(
            id: planned.id,
            exerciseId: substitute.id,
            orderIndex: planned.orderIndex,
            targetSets: replannedSets,
            restSeconds: planned.restSeconds,
            intensity: planned.intensity,
            reason: "Swapped to \(substitute.name)."
        )
        workout.exercises = orderedExercises
        persistWorkout()
    }

    private func persistWorkout() {
        hasLocalPlanEdits = true
        environment.todayWorkout = workout
        Task { try? await environment.saveTodayWorkout(workout) }
    }

    private func startSession() {
        Task {
            let plan = workoutPlanForStart()
            guard await WorkoutStartFlow.begin(
                from: plan,
                isResume: hasActiveSession,
                environment: environment,
                router: router
            ) != nil else { return }
        }
    }

    private func workoutPlanForStart() -> GeneratedWorkout {
        syncWorkoutFromEnvironment()
        if let latest = environment.todayWorkout,
           Calendar.current.isDate(latest.createdAt, inSameDayAs: Date()) {
            return latest
        }
        return workout
    }

    private func syncWorkoutFromEnvironment() {
        guard let latest = environment.todayWorkout else { return }
        let calendar = Calendar.current
        guard calendar.isDate(latest.createdAt, inSameDayAs: Date()) else { return }

        let localIsStale = !calendar.isDate(workout.createdAt, inSameDayAs: Date())
        let planReplaced = latest.id != workout.id
        guard localIsStale || planReplaced || (latest.id == workout.id && !hasLocalPlanEdits) else { return }

        if planReplaced {
            hasLocalPlanEdits = false
        }
        workout = latest
        orderedExercises = WorkoutPlanEditor.sortedExercises(latest.exercises)
    }
}

// MARK: - Exercise card (flat — no timeline connector)

private struct WorkoutPreviewExerciseCard: View {
    let planned: PlannedExercise
    let exercise: Exercise?
    let isFocus: Bool
    let onOpen: () -> Void
    let onSwap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: ForgeSpacing.s3) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: ForgeSpacing.s3) {
                    ExerciseThumbnailView(
                        exerciseId: planned.exerciseId,
                        primaryMuscle: exercise?.primaryMuscles.first?.displayName
                    )
                    .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 6) {
                        if isFocus {
                            Text("FOCUS")
                                .font(ForgeTypography.caption)
                                .tracking(1.5)
                                .foregroundStyle(ForgeColors.accent)
                        }

                        Text(exercise?.name ?? planned.exerciseId)
                            .font(ForgeTypography.heading)
                            .foregroundStyle(ForgeColors.foreground)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(setSummary)
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        if let exercise, !muscleLine(exercise).isEmpty {
                            Text(muscleLine(exercise))
                                .font(ForgeTypography.caption)
                                .foregroundStyle(ForgeColors.muted.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(ForgeColors.muted)
                        .padding(.top, 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("preview.exerciseRow.\(planned.id)")

            Button(action: onSwap) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ForgeColors.accent)
                    .frame(width: ForgeTarget.min, height: ForgeTarget.min)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Swap exercise")
            .accessibilityIdentifier("preview.swap.\(planned.exerciseId)")
        }
        .padding(ForgeSpacing.s4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ForgeColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ForgeColors.border, lineWidth: ForgeBorder.hairline)
        )
    }

    private var setSummary: String {
        let sets = planned.targetSets.count
        let reps = planned.targetSets.first.map { "\($0.targetRepsMin)–\($0.targetRepsMax) reps" } ?? "—"
        let weight = planned.targetSets.first?.targetWeightKg.map { " · \(Int($0))kg" } ?? ""
        return "\(sets) sets · \(reps)\(weight)"
    }

    private func muscleLine(_ exercise: Exercise) -> String {
        (exercise.primaryMuscles + exercise.secondaryMuscles).map(\.displayName).joined(separator: " · ")
    }
}

// MARK: - Exercise detail sheet

struct WorkoutPreviewExerciseDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let planned: PlannedExercise
    let exercise: Exercise?
    let isFocus: Bool
    let onSwap: () -> Void

    private var loadMode: LoadTrackingMode {
        exercise?.resolvedLoadTrackingMode ?? .supported
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ForgeScreenHeader(
                    title: exercise?.name ?? planned.exerciseId,
                    style: .compact,
                    presentation: .sheet,
                    eyebrow: isFocus ? "Focus Exercise" : "Planned Exercise",
                    subtitle: exercise.map { muscleLine($0) },
                    trailing: {
                        Button("Done") { dismiss() }
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.accent)
                    }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: ForgeSpacing.s5) {
                        HStack(spacing: ForgeSpacing.s2) {
                            ForgePill(label: "\(planned.targetSets.count) sets")
                            if planned.restSeconds > 0 {
                                ForgePill(label: "\(planned.restSeconds)s rest")
                            }
                        }

                        setsSection
                        actionSection
                    }
                    .padding(.horizontal, ForgeSpacing.s5)
                    .padding(.bottom, ForgeSpacing.s6)
                }
            }
            .background(ForgeColors.background)
            .navigationDestination(for: String.self) { exerciseId in
                ExerciseDetailView(exerciseId: exerciseId)
            }
            .forgeScreenNavigationHidden()
        }
        .presentationDetents([.medium, .large])
    }

    private var setsSection: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
            Text("PLANNED SETS")
                .font(ForgeTypography.label)
                .tracking(ForgeTracking.eyebrowWide)
                .foregroundStyle(ForgeColors.accent)

            ForgeCard {
                VStack(spacing: 0) {
                    setTableHeader

                    Rectangle()
                        .fill(ForgeColors.border)
                        .frame(height: ForgeBorder.hairline)

                    ForEach(Array(planned.targetSets.enumerated()), id: \.offset) { index, set in
                        setRow(index: index, set: set)
                        if index < planned.targetSets.count - 1 {
                            Rectangle()
                                .fill(ForgeColors.border)
                                .frame(height: ForgeBorder.hairline)
                        }
                    }
                }
            }
        }
    }

    private var setTableHeader: some View {
        HStack(spacing: ForgeSpacing.s2) {
            Text("SET")
                .frame(maxWidth: .infinity, alignment: .leading)
            if loadMode != .none {
                Text("LOAD")
                    .frame(width: 64, alignment: .trailing)
            }
            Text("REPS")
                .frame(width: 56, alignment: .trailing)
        }
        .font(ForgeTypography.caption)
        .foregroundStyle(ForgeColors.muted)
        .padding(.horizontal, ForgeSpacing.s4)
        .padding(.vertical, ForgeSpacing.s3)
    }

    private func setRow(index: Int, set: PlannedSet) -> some View {
        HStack(spacing: ForgeSpacing.s2) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Set \(index + 1)")
                    .font(ForgeTypography.heading)
                if set.isWarmup {
                    Text("Warm-up")
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if loadMode != .none {
                Text(WorkoutPreviewSetFormatter.loadLabel(for: set, loadMode: loadMode))
                    .font(ForgeTypography.metric)
                    .frame(width: 64, alignment: .trailing)
            }

            Text(WorkoutPreviewSetFormatter.repsLabel(for: set))
                .font(ForgeTypography.metric)
                .frame(width: 56, alignment: .trailing)
        }
        .foregroundStyle(ForgeColors.foreground)
        .padding(.horizontal, ForgeSpacing.s4)
        .padding(.vertical, ForgeSpacing.s3)
    }

    private var actionSection: some View {
        VStack(spacing: ForgeSpacing.s3) {
            ForgeButton(title: "Swap Exercise", style: .secondary, accessibilityIdentifier: "preview.detail.swap") {
                onSwap()
            }

            if exercise != nil {
                NavigationLink(value: planned.exerciseId) {
                    Text("View Exercise Guide")
                        .font(ForgeTypography.label)
                        .foregroundStyle(ForgeColors.accent)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: ForgeTarget.min)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("preview.detail.guide")
            }
        }
    }

    private func muscleLine(_ exercise: Exercise) -> String {
        (exercise.primaryMuscles + exercise.secondaryMuscles).map(\.displayName).joined(separator: " · ")
    }
}

// MARK: - Set formatting

enum WorkoutPreviewSetFormatter {
    static func repsLabel(for set: PlannedSet) -> String {
        if set.targetRepsMin == set.targetRepsMax {
            return "\(set.targetRepsMin)"
        }
        return "\(set.targetRepsMin)–\(set.targetRepsMax)"
    }

    static func loadLabel(for set: PlannedSet, loadMode: LoadTrackingMode) -> String {
        guard loadMode != .none else { return "BW" }
        if let weight = set.targetWeightKg {
            return "\(Int(weight.rounded()))kg"
        }
        return loadMode == .optional ? "—" : "BW"
    }

    static func summaryLine(for set: PlannedSet, exercise: Exercise?) -> String {
        let loadMode = exercise?.resolvedLoadTrackingMode ?? .supported
        let reps = repsLabel(for: set)
        let load = loadLabel(for: set, loadMode: loadMode)
        if loadMode == .none {
            return set.isWarmup ? "Warm-up · \(reps) reps" : "\(reps) reps"
        }
        return set.isWarmup ? "Warm-up · \(load) × \(reps)" : "\(load) × \(reps)"
    }
}
