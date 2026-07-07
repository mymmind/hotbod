import SwiftUI

struct WorkoutExerciseTimelineRow: View {
    let planned: PlannedExercise
    let exercise: Exercise?
    var isFocus: Bool = false
    var isLast: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            timelineColumn
            contentColumn
        }
        .padding(.vertical, 4)
    }

    private var timelineColumn: some View {
        VStack(spacing: 0) {
            ExerciseThumbnailView(
                exerciseId: planned.exerciseId,
                primaryMuscle: exercise?.primaryMuscles.first?.displayName
            )
            if !isLast {
                Rectangle()
                    .fill(ForgeColors.border)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 6)
            }
        }
        .frame(width: 72)
    }

    private var contentColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isFocus {
                Text("FOCUS EXERCISE")
                    .font(ForgeTypography.caption)
                    .tracking(1.5)
                    .foregroundStyle(ForgeColors.focusGradient)
            }

            Text(exercise?.name ?? planned.exerciseId)
                .font(ForgeTypography.heading)
                .fixedSize(horizontal: false, vertical: true)

            Text(setSummary)
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)

            if let exercise, !muscleLine(exercise).isEmpty {
                Text(muscleLine(exercise))
                    .font(ForgeTypography.caption)
                    .foregroundStyle(ForgeColors.muted.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .padding(.bottom, isLast ? 0 : 16)
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
