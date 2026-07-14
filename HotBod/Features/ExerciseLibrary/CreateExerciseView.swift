import SwiftUI

struct CreateExerciseView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedMuscles: Set<MuscleGroup> = []
    @State private var selectedEquipment: Set<Equipment> = [.dumbbell]
    @State private var movementPattern: MovementPattern = .isolation
    @State private var difficulty: ExerciseDifficulty = .intermediate
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.muted)
                        TextField("Exercise name", text: $name)
                            .padding(12)
                            .overlay(Rectangle().stroke(ForgeColors.border, lineWidth: 1))
                    }

                    chipSection(
                        title: "Primary muscles",
                        muscles: MuscleGroup.preferenceSelectable,
                        selection: $selectedMuscles
                    )
                    equipmentSection

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Movement pattern")
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.muted)
                        Menu(movementPattern.displayName) {
                            ForEach(MovementPattern.allCases, id: \.self) { pattern in
                                Button(pattern.displayName) { movementPattern = pattern }
                            }
                        }
                        .font(ForgeTypography.body)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Difficulty")
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.muted)
                        Menu(difficulty.displayName) {
                            ForEach(ExerciseDifficulty.allCases, id: \.self) { level in
                                Button(level.displayName) { difficulty = level }
                            }
                        }
                        .font(ForgeTypography.body)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.destructive)
                    }

                    ForgeButton(title: isSaving ? "Saving..." : "Create Exercise", style: .accent) {
                        Task { await save() }
                    }
                    .disabled(isSaving || !canSave)
                    .accessibilityIdentifier("createExercise.save")
                }
                .padding()
            }
            .background(ForgeColors.background)
            .navigationTitle("Create Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !selectedMuscles.isEmpty
            && !selectedEquipment.isEmpty
    }

    private func chipSection(
        title: String,
        muscles: [MuscleGroup],
        selection: Binding<Set<MuscleGroup>>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                ForEach(muscles) { muscle in
                    SelectableChip(
                        title: muscle.displayName,
                        isSelected: selection.wrappedValue.contains(muscle)
                    ) {
                        if selection.wrappedValue.contains(muscle) {
                            selection.wrappedValue.remove(muscle)
                        } else {
                            selection.wrappedValue.insert(muscle)
                        }
                    }
                }
            }
        }
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Equipment")
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                ForEach(Equipment.allCases) { equipment in
                    SelectableChip(
                        title: equipment.displayName,
                        isSelected: selectedEquipment.contains(equipment)
                    ) {
                        if selectedEquipment.contains(equipment) {
                            selectedEquipment.remove(equipment)
                        } else {
                            selectedEquipment.insert(equipment)
                        }
                    }
                }
            }
        }
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let slugBase = trimmed.lowercased().replacingOccurrences(of: " ", with: "-")
        let id = "custom_\(UUID().uuidString.lowercased().prefix(8))"

        let exercise = Exercise(
            id: id,
            name: trimmed,
            slug: slugBase,
            primaryMuscles: Array(selectedMuscles),
            secondaryMuscles: [],
            equipment: Array(selectedEquipment),
            movementPattern: movementPattern,
            difficulty: difficulty,
            forceType: nil,
            mechanics: movementPattern.inferredMechanics,
            instructions: ["Perform with controlled form."],
            formCues: [],
            commonMistakes: [],
            contraindications: [],
            substitutions: [],
            progressions: [],
            regressions: [],
            demoVideos: [],
            imageUrl: nil,
            tags: ["custom"],
            isCustom: true
        )

        do {
            _ = try await environment.createCustomExercise(exercise)
            dismiss()
        } catch {
            errorMessage = "Could not save exercise."
        }
    }
}

#Preview {
    CreateExerciseView()
        .environment(AppEnvironment())
}
