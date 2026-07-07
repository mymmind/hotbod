import SwiftUI

struct ActiveWorkoutPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession
    let currentExerciseIndex: Int
    let exerciseMap: [String: Exercise]

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
                ActiveWorkoutTimelineRow(
                    workoutExercise: workoutExercise,
                    exercise: exerciseMap[workoutExercise.exerciseId],
                    status: rowStatus(for: workoutExercise, at: index),
                    isLast: index == sortedExercises.count - 1
                )
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 24)
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
