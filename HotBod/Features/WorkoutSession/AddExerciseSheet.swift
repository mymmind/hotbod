import SwiftUI

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exercises: [Exercise]
    let usedExerciseIds: Set<String>
    let onSelect: (Exercise) -> Void

    @State private var query = ""

    private var filtered: [Exercise] {
        let base = exercises.filter { !usedExerciseIds.contains($0.id) && $0.preference != .excluded }
        guard !query.isEmpty else { return base.sorted { $0.name < $1.name } }
        let q = query.lowercased()
        return base.filter {
            $0.name.lowercased().contains(q)
                || $0.primaryMuscles.contains(where: { $0.displayName.lowercased().contains(q) })
        }
        .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Search exercises", text: $query)
                    .padding(12)
                    .overlay(Rectangle().stroke(ForgeColors.border, lineWidth: 1))
                    .padding(ForgeSpacing.s4)
                    .accessibilityIdentifier("session.addExercise.search")

                List(filtered) { exercise in
                    Button {
                        onSelect(exercise)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(ForgeTypography.heading)
                                .foregroundStyle(ForgeColors.textPrimary)
                            Text(exercise.primaryMuscles.map(\.displayName).joined(separator: ", "))
                                .font(ForgeTypography.caption)
                                .foregroundStyle(ForgeColors.muted)
                        }
                    }
                    .accessibilityIdentifier("session.addExercise.row.\(exercise.id)")
                }
                .listStyle(.plain)
            }
            .background(ForgeColors.background)
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AddExerciseSheet(
        exercises: [],
        usedExerciseIds: [],
        onSelect: { _ in }
    )
}
