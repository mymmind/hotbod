import SwiftUI

struct ExerciseDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    let exerciseId: String

    @State private var exercise: Exercise?
    @State private var isFavorite = false
    @State private var selectedTab: DetailTab = .instructions

    private enum DetailTab: String, CaseIterable {
        case instructions = "Instructions"
        case target = "Target"
        case equipment = "Equipment"
    }

    private var isRouterPresented: Bool {
        if case .exerciseDetail(let id) = router.route {
            return id == exerciseId
        }
        return false
    }

    var body: some View {
        ScrollView {
            if let exercise {
                VStack(alignment: .leading, spacing: 0) {
                    ExerciseDetailMediaHero(
                        exerciseId: exerciseId,
                        mediaProvider: environment.exerciseMediaProvider,
                        onBack: handleBack
                    )

                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .top) {
                            titleSection(exercise)
                            Spacer(minLength: 0)
                            exerciseActionsMenu
                        }
                        tabBar
                        tabContent(for: exercise)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
                    .task { await load() }
            }
        }
        .background(ForgeColors.background)
        .navigationBarHidden(true)
    }

    private var exerciseActionsMenu: some View {
        Menu {
            Button(isFavorite ? "Remove Favorite" : "Add Favorite") {
                Task {
                    isFavorite.toggle()
                    try? await environment.updateExerciseFavorite(
                        id: exerciseId,
                        isFavorite: isFavorite
                    )
                }
            }
            Button("Avoid Exercise", role: .destructive) {
                Task {
                    try? await environment.updateExerciseAvoided(
                        id: exerciseId,
                        isAvoided: true
                    )
                    handleBack()
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(ForgeColors.muted)
                .padding(8)
        }
    }

    // MARK: - Sections

    private func titleSection(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.name)
                .font(ForgeTypography.displayAthletic)
                .foregroundStyle(ForgeColors.foreground)

            if !alsoCalledLine(for: exercise).isEmpty {
                Text("Also called: \(alsoCalledLine(for: exercise))")
                    .font(ForgeTypography.body)
                    .foregroundStyle(ForgeColors.muted)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(ForgeMotion.quick) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(ForgeTypography.caption)
                        .foregroundStyle(
                            selectedTab == tab ? ForgeColors.foreground : ForgeColors.muted
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == tab
                                ? ForgeColors.foreground.opacity(0.1)
                                : Color.clear
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(ForgeColors.foreground.opacity(0.05))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func tabContent(for exercise: Exercise) -> some View {
        switch selectedTab {
        case .instructions:
            instructionsContent(exercise)
        case .target:
            targetContent(exercise)
        case .equipment:
            equipmentContent(exercise)
        }
    }

    private func instructionsContent(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(instructionParagraphs(for: exercise), id: \.self) { paragraph in
                Text(paragraph)
                    .font(ForgeTypography.body)
                    .foregroundStyle(ForgeColors.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !exercise.commonMistakes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("COMMON MISTAKES")
                        .font(ForgeTypography.caption)
                        .tracking(1.5)
                        .foregroundStyle(ForgeColors.muted)

                    ForEach(exercise.commonMistakes, id: \.self) { mistake in
                        Text(mistake)
                            .font(ForgeTypography.body)
                            .foregroundStyle(ForgeColors.foreground)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func targetContent(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            muscleGroup("Primary", exercise.primaryMuscles.map(\.displayName))
            if !exercise.secondaryMuscles.isEmpty {
                muscleGroup("Secondary", exercise.secondaryMuscles.map(\.displayName))
            }
            detailRow("Movement", exercise.movementPattern.displayName)
            if let mechanics = exercise.mechanics {
                detailRow("Mechanics", mechanics == .compound ? "Compound" : "Isolation")
            }
            if let force = exercise.forceType {
                detailRow("Force", force == .push ? "Push" : force == .pull ? "Pull" : "Static hold")
            }
        }
    }

    private func equipmentContent(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(exercise.equipment, id: \.self) { item in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ForgeColors.accent)
                        .frame(width: 4, height: 20)
                    Text(item.displayName)
                        .font(ForgeTypography.body)
                        .foregroundStyle(ForgeColors.foreground)
                }
            }

            if exercise.equipment.isEmpty {
                Text("No equipment required.")
                    .font(ForgeTypography.body)
                    .foregroundStyle(ForgeColors.muted)
            }
        }
    }

    // MARK: - Helpers

    private func muscleGroup(_ label: String, _ muscles: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(ForgeTypography.caption)
                .tracking(1.5)
                .foregroundStyle(ForgeColors.muted)
            Text(muscles.joined(separator: ", "))
                .font(ForgeTypography.body)
                .foregroundStyle(ForgeColors.foreground)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(ForgeTypography.caption)
                .tracking(1.5)
                .foregroundStyle(ForgeColors.muted)
            Text(value)
                .font(ForgeTypography.body)
                .foregroundStyle(ForgeColors.foreground)
        }
    }

    private func alsoCalledLine(for exercise: Exercise) -> String {
        if !exercise.aliases.isEmpty {
            return exercise.aliases.joined(separator: ", ")
        }
        return exercise.tags
            .map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
            .joined(separator: ", ")
    }

    private func instructionParagraphs(for exercise: Exercise) -> [String] {
        var paragraphs = exercise.instructions
        paragraphs.append(contentsOf: exercise.formCues)
        return paragraphs
    }

    private func handleBack() {
        if isRouterPresented {
            router.dismissRoute()
        } else {
            dismiss()
        }
    }

    private func load() async {
        exercise = await environment.fetchExercise(id: exerciseId)
        isFavorite = exercise?.isFavorite ?? false
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(exerciseId: "bench_press")
            .environment(AppEnvironment())
            .environment(AppRouter())
    }
}
