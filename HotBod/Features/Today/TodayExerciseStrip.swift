import SwiftUI

struct TodayExerciseStrip: View {
    let workout: GeneratedWorkout
    let exercises: [String: Exercise]
    var onPreview: (() -> Void)? = nil

    private let chipWidth: CGFloat = 72
    private let titleLineCount = 2

    private var sortedExercises: [PlannedExercise] {
        workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("SESSION PREVIEW")
                    .font(ForgeTypography.caption)
                    .tracking(2)
                    .foregroundStyle(ForgeColors.muted)
                Spacer()
                if let onPreview {
                    Button("See All", action: onPreview)
                        .font(ForgeTypography.caption)
                        .foregroundStyle(ForgeColors.accent)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(sortedExercises) { planned in
                        exerciseChip(planned)
                    }
                }
                .padding(.vertical, 2)
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

    private func exerciseChip(_ planned: PlannedExercise) -> some View {
        let exercise = exercises[planned.exerciseId]
        return VStack(alignment: .leading, spacing: 8) {
            ExerciseThumbnailView(
                exerciseId: planned.exerciseId,
                primaryMuscle: exercise?.primaryMuscles.first?.displayName
            )

            Text(exercise?.name ?? planned.exerciseId)
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.foreground)
                .lineLimit(titleLineCount)
                .multilineTextAlignment(.leading)
                .frame(width: chipWidth, height: titleBlockHeight, alignment: .topLeading)

            Text("\(planned.targetSets.count) sets")
                .font(ForgeTypography.tabLabel.weight(.semibold).monospaced())
                .foregroundStyle(ForgeColors.muted)
        }
        .frame(width: chipWidth, alignment: .topLeading)
    }

    private var titleBlockHeight: CGFloat {
        let font = UIFont.systemFont(ofSize: 13, weight: .medium)
        let lineHeight = font.lineHeight
        return ceil(lineHeight * CGFloat(titleLineCount))
    }
}

#Preview {
    TodayExerciseStrip(
        workout: GeneratedWorkout(
            id: UUID(),
            title: "Upper Strength",
            estimatedDurationMinutes: 45,
            focus: [.chest, .back],
            exercises: [],
            rationale: "",
            safetyNotes: [],
            generatedBy: .rulesEngine,
            createdAt: .now
        ),
        exercises: [:]
    )
    .padding()
}
