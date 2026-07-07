import SwiftUI

enum WorkoutSessionMenuAction {
    case previewWorkout
    case workoutExplanation
    case endWorkout
    case cancelWorkout
}

struct WorkoutSessionHeaderView: View {
    var onExit: (() -> Void)? = nil
    var onMenuAction: ((WorkoutSessionMenuAction) -> Void)? = nil
    let sessionTitle: String
    let exerciseName: String
    let muscleLine: String
    let currentExerciseIndex: Int
    let exerciseCount: Int
    let completedSets: Int
    let totalSets: Int
    let currentExerciseCompletedSets: Int
    let currentExerciseTotalSets: Int
    let startedAt: Date?
    let bodyWeightKg: Double

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = elapsedSeconds(at: context.date)
            let calories = WorkoutSessionCalculator.estimatedCaloriesBurned(
                elapsedSeconds: elapsed,
                bodyWeightKg: bodyWeightKg
            )
            VStack(spacing: 0) {
                sessionToolbar(elapsed: elapsed)
                sessionHero(elapsed: elapsed, calories: calories)
            }
        }
    }

    // MARK: - Toolbar

    private func sessionToolbar(elapsed: Int) -> some View {
        HStack(spacing: ForgeSpacing.s2) {
            if let onExit {
                toolbarButton(systemName: "chevron.left", label: "Exit workout", action: onExit)
            }

            Text(sessionTitle)
                .font(ForgeTypography.tabLabel.weight(.semibold))
                .tracking(ForgeTracking.tight)
                .foregroundStyle(ForgeColors.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            if let onMenuAction {
                Menu {
                    Button { onMenuAction(.previewWorkout) } label: {
                        Label("Preview Workout", systemImage: "list.bullet")
                    }
                    Button { onMenuAction(.workoutExplanation) } label: {
                        Label("Workout Explanation", systemImage: "text.alignleft")
                    }
                    Divider()
                    Button(role: .destructive) { onMenuAction(.endWorkout) } label: {
                        Label("End Workout", systemImage: "flag.checkered")
                    }
                    Button(role: .destructive) { onMenuAction(.cancelWorkout) } label: {
                        Label("Cancel Workout", systemImage: "xmark.circle")
                    }
                } label: {
                    toolbarButtonLabel(systemName: "ellipsis")
                }
                .accessibilityLabel("Workout options")
            }

            liveTimer(seconds: elapsed)
        }
        .padding(.horizontal, ForgeSpacing.s4)
        .padding(.vertical, ForgeSpacing.s3)
        .background(ForgeColors.background)
    }

    private func toolbarButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            toolbarButtonLabel(systemName: systemName)
        }
        .buttonStyle(.plain)
        .frame(width: ForgeTarget.min, height: ForgeTarget.min)
        .contentShape(Rectangle())
        .accessibilityLabel(label)
    }

    private func toolbarButtonLabel(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.caption.weight(.bold))
            .foregroundStyle(ForgeColors.textPrimary)
            .frame(width: 36, height: 36)
            .overlay(Circle().stroke(ForgeColors.border, lineWidth: ForgeBorder.hairline))
    }

    private func liveTimer(seconds: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ForgeColors.accent)
                .frame(width: 6, height: 6)
            Text(WorkoutSessionCalculator.formattedElapsed(seconds: seconds))
                .font(ForgeTypography.metric)
                .foregroundStyle(ForgeColors.textPrimary)
                .contentTransition(.numericText())
        }
        .accessibilityLabel("Elapsed time \(WorkoutSessionCalculator.formattedElapsed(seconds: seconds))")
    }

    // MARK: - Hero

    private func sessionHero(elapsed: Int, calories: Int) -> some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s4) {
            VStack(alignment: .leading, spacing: ForgeSpacing.s2) {
                Text("Exercise \(currentExerciseIndex + 1) of \(exerciseCount)")
                    .font(ForgeTypography.label)
                    .tracking(ForgeTracking.eyebrowWide)
                    .foregroundStyle(ForgeColors.accent)

                Text(exerciseName)
                    .font(ForgeTypography.display)
                    .foregroundStyle(ForgeColors.textOnInverse)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .id(exerciseName)
                    .transition(ForgeMotion.exerciseChange)
                    .forgeMetricPulse(value: currentExerciseIndex)

                if !muscleLine.isEmpty {
                    Text(muscleLine)
                        .font(ForgeTypography.body)
                        .foregroundStyle(ForgeColors.textOnInverse.opacity(0.55))
                        .lineLimit(2)
                }
            }

            exerciseSegments

            sessionMetrics(calories: calories)
        }
        .padding(.horizontal, ForgeSpacing.s4)
        .padding(.top, ForgeSpacing.s5)
        .padding(.bottom, ForgeSpacing.s6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { heroBackground }
        .animation(ForgeMotion.exercise, value: currentExerciseIndex)
        .animation(ForgeMotion.quick, value: currentExerciseCompletedSets)
    }

    private var exerciseSegments: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(exerciseCount, 1), id: \.self) { index in
                Rectangle()
                    .fill(segmentColor(for: index))
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .animation(ForgeMotion.standard.delay(Double(index) * 0.02), value: currentExerciseIndex)
            }
        }
        .accessibilityLabel("Exercise \(currentExerciseIndex + 1) of \(exerciseCount)")
    }

    private func segmentColor(for index: Int) -> Color {
        if index < currentExerciseIndex { return ForgeColors.accentGreen }
        if index == currentExerciseIndex { return ForgeColors.accent }
        return ForgeColors.textOnInverse.opacity(0.15)
    }

    private func sessionMetrics(calories: Int) -> some View {
        HStack(spacing: 0) {
            metricColumn(
                value: "\(currentExerciseCompletedSets)/\(currentExerciseTotalSets)",
                label: "This exercise"
            )
            metricDivider
            metricColumn(value: "\(completedSets)/\(totalSets)", label: "Session sets")
            metricDivider
            metricColumn(value: "\(calories)", label: "Cal")
        }
    }

    private func metricColumn(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(ForgeTypography.metric)
                .foregroundStyle(ForgeColors.textOnInverse)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label.uppercased())
                .font(ForgeTypography.tabLabel)
                .tracking(ForgeTracking.tight)
                .foregroundStyle(ForgeColors.textOnInverse.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(ForgeColors.textOnInverse.opacity(0.12))
            .frame(width: 1, height: 32)
            .padding(.horizontal, ForgeSpacing.s3)
    }

    private var heroBackground: some View {
        ZStack(alignment: .bottom) {
            ForgeColors.surfaceInverse

            LinearGradient(
                colors: [ForgeColors.accent.opacity(0.14), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func elapsedSeconds(at date: Date) -> Int {
        guard let startedAt else { return 0 }
        return max(0, Int(date.timeIntervalSince(startedAt)))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 0) {
            WorkoutSessionHeaderView(
                sessionTitle: "Upper Hypertrophy",
                exerciseName: "Landmine Press",
                muscleLine: "Shoulders · Chest · Triceps",
                currentExerciseIndex: 0,
                exerciseCount: 7,
                completedSets: 0,
                totalSets: 23,
                currentExerciseCompletedSets: 0,
                currentExerciseTotalSets: 3,
                startedAt: Date().addingTimeInterval(-65),
                bodyWeightKg: 80
            )
            Rectangle().fill(ForgeColors.border).frame(height: 200)
        }
    }
    .background(ForgeColors.background)
}
