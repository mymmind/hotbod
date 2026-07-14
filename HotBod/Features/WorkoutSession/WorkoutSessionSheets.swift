import SwiftUI

struct ActiveWorkoutPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession
    let currentExerciseIndex: Int
    let furthestExerciseIndex: Int
    let exerciseMap: [String: Exercise]
    var canSwapAtIndex: ((Int) -> Bool)? = nil
    var onSelectExercise: ((Int) -> Void)? = nil
    var onSwapExercise: ((Int) -> Void)? = nil

    private var sortedExercises: [WorkoutExercise] {
        session.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    previewHeader
                    exerciseTimeline
                }
            }
            .background(ForgeColors.background)
            .navigationTitle("Workout Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var previewHeader: some View {
        let completedSets = WorkoutSessionCalculator.completedSetCount(session: session)
        let totalSets = WorkoutSessionCalculator.totalPlannedSets(exercises: session.exercises)

        return VStack(alignment: .leading, spacing: 12) {
            Text(session.title)
                .font(ForgeTypography.heading)
            Text("\(completedSets) of \(totalSets) sets logged · Exercise \(currentExerciseIndex + 1) of \(session.exercises.count)")
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var exerciseTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sortedExercises.enumerated()), id: \.element.id) { index, workoutExercise in
                timelineRow(workoutExercise: workoutExercise, index: index)
            }
        }
        .padding(.bottom, 24)
    }

    private func timelineRow(workoutExercise: WorkoutExercise, index: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Group {
                if onSelectExercise != nil {
                    Button {
                        onSelectExercise?(index)
                    } label: {
                        ActiveWorkoutTimelineRow(
                            workoutExercise: workoutExercise,
                            exercise: exerciseMap[workoutExercise.exerciseId],
                            status: rowStatus(for: workoutExercise, at: index),
                            isLast: index == sortedExercises.count - 1,
                            showsJumpHint: index != currentExerciseIndex
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("session.previewExercise.\(index)")
                } else {
                    ActiveWorkoutTimelineRow(
                        workoutExercise: workoutExercise,
                        exercise: exerciseMap[workoutExercise.exerciseId],
                        status: rowStatus(for: workoutExercise, at: index),
                        isLast: index == sortedExercises.count - 1
                    )
                }
            }

            if canSwapAtIndex?(index) == true, let onSwapExercise {
                Button {
                    onSwapExercise(index)
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ForgeColors.accent)
                        .frame(width: ForgeTarget.min, height: ForgeTarget.min)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Swap exercise")
                .accessibilityIdentifier("session.previewSwap.\(index)")
            }
        }
        .padding(.horizontal, 20)
    }

    private func rowStatus(for exercise: WorkoutExercise, at index: Int) -> ActiveWorkoutRowStatus {
        if exercise.wasSkipped { return .skipped }
        if index < currentExerciseIndex { return .completed }
        if index == currentExerciseIndex { return .current }
        return .upcoming
    }
}

enum ActiveWorkoutRowStatus {
    case completed, current, upcoming, skipped
}

private struct ActiveWorkoutTimelineRow: View {
    let workoutExercise: WorkoutExercise
    let exercise: Exercise?
    let status: ActiveWorkoutRowStatus
    let isLast: Bool
    var showsJumpHint: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    ExerciseThumbnailView(
                        exerciseId: workoutExercise.exerciseId,
                        primaryMuscle: exercise?.primaryMuscles.first?.displayName
                    )
                    statusBadge
                }
                if !isLast {
                    Rectangle()
                        .fill(ForgeColors.border)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .frame(width: 72)

            VStack(alignment: .leading, spacing: 6) {
                if status == .current {
                    Text("CURRENT")
                        .font(ForgeTypography.caption)
                        .tracking(1.5)
                        .foregroundStyle(ForgeColors.accent)
                }

                Text(exercise?.name ?? workoutExercise.exerciseId)
                    .font(ForgeTypography.heading)
                    .foregroundStyle(status == .upcoming ? ForgeColors.muted : ForgeColors.foreground)

                Text(progressLine)
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.muted)

                if showsJumpHint {
                    Text("Tap to view")
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .padding(.bottom, isLast ? 0 : 16)
        }
        .padding(.vertical, 4)
        .opacity(status == .upcoming ? 0.72 : 1)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(ForgeColors.accentGreen)
                .background(Circle().fill(ForgeColors.surface))
                .offset(x: 4, y: 4)
        case .skipped:
            Image(systemName: "forward.fill")
                .font(.caption2)
                .foregroundStyle(ForgeColors.muted)
                .background(Circle().fill(ForgeColors.surface))
                .offset(x: 4, y: 4)
        case .current:
            Circle()
                .fill(ForgeColors.accent)
                .frame(width: 10, height: 10)
                .offset(x: 4, y: 4)
        case .upcoming:
            EmptyView()
        }
    }

    private var progressLine: String {
        if workoutExercise.wasSkipped { return "Skipped" }
        let done = workoutExercise.completedSets.count
        let total = workoutExercise.plannedSets.count
        return "\(done) / \(total) sets"
    }
}

struct WorkoutExplanationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let rationale: String
    let selectionRationale: [String]
    let safetyNotes: [String]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForgeCard {
                        ForgeSectionHeader(title: "Why This Workout?")
                        Text(rationale.isEmpty ? "This session targets your current training focus with equipment you have available." : rationale)
                            .font(ForgeTypography.body)
                    }

                    if !selectionRationale.isEmpty {
                        ForgeCard {
                            ForgeSectionHeader(title: "Selection Details")
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(selectionRationale, id: \.self) { line in
                                    Text("· \(line)")
                                        .font(ForgeTypography.body)
                                        .foregroundStyle(ForgeColors.textSecondary)
                                }
                            }
                        }
                    }

                    if !safetyNotes.isEmpty {
                        ForgeCard {
                            ForgeSectionHeader(title: "Safety Notes")
                            ForEach(safetyNotes, id: \.self) { note in
                                Text("· \(note)")
                                    .font(ForgeTypography.body)
                                    .foregroundStyle(ForgeColors.muted)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(ForgeColors.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
