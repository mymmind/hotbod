import SwiftUI

struct ExerciseLibraryView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var exercises: [Exercise] = []
    @State private var query = ""
    @State private var selectedMuscle: MuscleGroup?
    @State private var selectedEquipment: Equipment?

    private var filterSignature: String {
        "\(query)-\(selectedMuscle?.rawValue ?? "all")-\(selectedEquipment?.rawValue ?? "all")"
    }

    var body: some View {
        VStack(spacing: 0) {
            ForgeScreenHeader(
                title: "Exercise Library",
                style: .compact,
                eyebrow: "Train",
                subtitle: "Search, filter, and favorite movements.",
                leading: {
                    ForgeHeaderBackButton { dismiss() }
                }
            )
            searchBar
            filterBar
            List(filtered) { exercise in
                NavigationLink(destination: ExerciseDetailView(exerciseId: exercise.id)) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(exercise.name).font(ForgeTypography.heading)
                            Text(exercise.primaryMuscles.map(\.displayName).joined(separator: ", "))
                                .font(ForgeTypography.caption)
                                .foregroundStyle(ForgeColors.muted)
                        }
                        Spacer()
                        if exercise.isFavorite {
                            Image(systemName: "star.fill")
                                .foregroundStyle(ForgeColors.accentAmber)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .forgeAnimatedContent(id: filterSignature)
            .animation(ForgeMotion.standard, value: filterSignature)
        }
        .forgeScreenNavigationHidden()
        .task { await load() }
    }

    private var searchBar: some View {
        TextField("Search exercises", text: $query)
            .padding(12)
            .overlay(Rectangle().stroke(ForgeColors.border, lineWidth: 1))
            .padding()
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                Menu("Muscle") {
                    Button("All") { selectedMuscle = nil }
                    ForEach(MuscleGroup.allCases) { m in
                        Button(m.displayName) { selectedMuscle = m }
                    }
                }
                Menu("Equipment") {
                    Button("All") { selectedEquipment = nil }
                    ForEach(Equipment.allCases) { e in
                        Button(e.displayName) { selectedEquipment = e }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var filtered: [Exercise] {
        ExerciseFilter.apply(
            exercises: exercises,
            query: query,
            filters: ExerciseFilters(muscleGroup: selectedMuscle, equipment: selectedEquipment)
        )
    }

    private func load() async {
        exercises = await environment.fetchAllExercises()
    }
}

