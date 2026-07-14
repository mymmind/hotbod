import Foundation

actor LocalExerciseRepository: ExerciseRepository {
    private static let preferencesKey = "exercise_preferences.json"
    private static let customExercisesKey = "custom_exercises.json"

    private var exercises: [Exercise] = []
    private var preferenceOverrides: [String: ExercisePreference] = [:]
    private let substitutionGroups: [ExerciseSubstitutionGroup]
    private var exercisesByGroup: [String: [Exercise]]

    init() {
        let seed = ExerciseCatalogLoader.loadExercises()
        let customs = PersistenceHelper.load([Exercise].self, from: Self.customExercisesKey) ?? []
        exercises = Self.mergeCatalog(seed: seed, customs: customs)
        let overrides = PersistenceHelper.load([String: ExercisePreference].self, from: Self.preferencesKey) ?? [:]
        for index in exercises.indices {
            if let preference = overrides[exercises[index].id] {
                exercises[index].preference = preference
            }
        }
        preferenceOverrides = overrides
        substitutionGroups = ExerciseCatalogLoader.loadSubstitutionGroups()
        exercisesByGroup = ExerciseCatalogLoader.buildGroupIndex(exercises: exercises)
    }

    private static func mergeCatalog(seed: [Exercise], customs: [Exercise]) -> [Exercise] {
        let dedupedCustoms = ExerciseCatalog.indexedById(customs)
        var merged = seed.filter { dedupedCustoms[$0.id] == nil }
        merged.append(contentsOf: dedupedCustoms.values.map { custom in
            var updated = custom
            updated.isCustom = true
            return updated
        })
        return merged
    }

    private func rebuildGroupIndex() {
        exercisesByGroup = ExerciseCatalogLoader.buildGroupIndex(exercises: exercises)
    }

    private func persistPreferences() {
        var saved: [String: ExercisePreference] = [:]
        for exercise in exercises where exercise.preference != .neutral {
            saved[exercise.id] = exercise.preference
        }
        PersistenceHelper.save(saved, to: Self.preferencesKey)
    }

    private func persistCustomExercises() {
        let customs = ExerciseCatalog.indexedById(exercises.filter(\.isCustom)).values.sorted { $0.name < $1.name }
        PersistenceHelper.save(Array(customs), to: Self.customExercisesKey)
    }

    func fetchAll() async throws -> [Exercise] {
        exercises
    }

    func fetch(id: String) async throws -> Exercise? {
        exercises.first { $0.id == id }
    }

    func search(query: String, filters: ExerciseFilters) async throws -> [Exercise] {
        ExerciseFilter.apply(exercises: exercises, query: query, filters: filters)
    }

    func fetchSubstitutionGroups() async throws -> [ExerciseSubstitutionGroup] {
        substitutionGroups
    }

    func fetchExercises(inGroup groupId: String) async throws -> [Exercise] {
        exercisesByGroup[groupId] ?? []
    }

    func substitutionGroup(for exerciseId: String) async throws -> ExerciseSubstitutionGroup? {
        ExerciseCatalog.substitutionGroup(for: exerciseId, exercises: exercises, groups: substitutionGroups)
    }

    func substitutes(
        for exerciseId: String,
        availableEquipment: [Equipment],
        injuries: [BodyLimitation],
        excludeIds: Set<String> = []
    ) async throws -> [Exercise] {
        ExerciseCatalog.substitutes(
            for: exerciseId,
            from: exercises,
            availableEquipment: availableEquipment,
            injuries: injuries,
            excludeIds: excludeIds
        )
    }

    func updatePreference(id: String, preference: ExercisePreference) async throws {
        guard let index = exercises.firstIndex(where: { $0.id == id }) else { return }
        exercises[index].preference = preference
        if preference == .neutral {
            preferenceOverrides.removeValue(forKey: id)
        } else {
            preferenceOverrides[id] = preference
        }
        persistPreferences()
    }

    func updateFavorite(id: String, isFavorite: Bool) async throws {
        let current = exercises.first { $0.id == id }?.preference ?? .neutral
        let next: ExercisePreference
        if isFavorite {
            next = .favorite
        } else if current == .favorite {
            next = .neutral
        } else {
            next = current
        }
        try await updatePreference(id: id, preference: next)
    }

    func updateAvoided(id: String, isAvoided: Bool) async throws {
        let current = exercises.first { $0.id == id }?.preference ?? .neutral
        let next: ExercisePreference
        if isAvoided {
            next = .excluded
        } else if current == .excluded {
            next = .neutral
        } else {
            next = current
        }
        try await updatePreference(id: id, preference: next)
    }

    func resetUserPreferences() async throws {
        for index in exercises.indices {
            exercises[index].preference = .neutral
        }
        preferenceOverrides.removeAll()
        persistPreferences()
    }

    func resetCustomExercises() async throws {
        let seed = ExerciseCatalogLoader.loadExercises()
        exercises = seed
        for index in exercises.indices {
            exercises[index].preference = .neutral
        }
        preferenceOverrides.removeAll()
        rebuildGroupIndex()
        persistPreferences()
        persistCustomExercises()
    }

    func preferenceOverrides() async -> [String: ExercisePreference] {
        preferenceOverrides
    }

    func applyPreferenceOverrides(_ overrides: [String: ExercisePreference]) async throws {
        preferenceOverrides = overrides
        for index in exercises.indices {
            exercises[index].preference = overrides[exercises[index].id] ?? .neutral
        }
        persistPreferences()
    }

    func createCustomExercise(_ exercise: Exercise) async throws -> Exercise {
        var custom = exercise
        custom.isCustom = true
        if let index = exercises.firstIndex(where: { $0.id == custom.id }) {
            exercises[index] = custom
        } else {
            exercises.append(custom)
        }
        rebuildGroupIndex()
        persistCustomExercises()
        return custom
    }

    func deleteCustomExercise(id: String) async throws {
        guard exercises.contains(where: { $0.id == id && $0.isCustom }) else { return }
        exercises.removeAll { $0.id == id }
        preferenceOverrides.removeValue(forKey: id)
        rebuildGroupIndex()
        persistPreferences()
        persistCustomExercises()
    }
}

enum ExerciseSeedLoader {
    static func load() -> [Exercise] {
        ExerciseCatalogLoader.loadExercises()
    }

    static func loadSeed() -> [Exercise] {
        guard let url = ExerciseCatalogLoader.resourceBundle.url(forResource: "ExerciseSeed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let seed = try? JSONDecoder().decode([ExerciseSeedDTO].self, from: data) else {
            return fallbackExercises()
        }
        return seed.map { $0.toExercise() }
    }

    private static func fallbackExercises() -> [Exercise] {
        [
            fallbackBenchPress(),
            fallbackSquat(),
            fallbackRomanianDeadlift(),
            fallbackPullUp(),
            fallbackDumbbellShoulderPress(),
            fallbackCableRow()
        ]
    }

    private static func fallbackBenchPress() -> Exercise {
        Exercise(
            id: "bench_press",
            name: "Bench Press",
            slug: "bench-press",
            primaryMuscles: [.chest],
            secondaryMuscles: [.shoulders, .triceps],
            equipment: [.barbell, .bench],
            movementPattern: .horizontalPush,
            difficulty: .intermediate,
            forceType: .push,
            mechanics: .compound,
            instructions: ["Lie on bench.", "Lower bar to chest.", "Press up."],
            formCues: ["Retract scapula."],
            commonMistakes: ["Bouncing bar."],
            contraindications: [],
            substitutions: ["dumbbell_press"],
            progressions: [],
            regressions: ["push_up"],
            demoVideos: [],
            imageUrl: nil,
            tags: ["compound"]
        )
    }

    private static func fallbackSquat() -> Exercise {
        Exercise(
            id: "squat",
            name: "Back Squat",
            slug: "back-squat",
            primaryMuscles: [.quads, .glutes],
            secondaryMuscles: [.hamstrings],
            equipment: [.barbell, .squatRack],
            movementPattern: .squat,
            difficulty: .intermediate,
            forceType: .push,
            mechanics: .compound,
            instructions: ["Set the bar on upper back.", "Brace and squat to depth.", "Drive up through midfoot."],
            formCues: ["Brace core before descent."],
            commonMistakes: ["Knees collapsing inward."],
            contraindications: [],
            substitutions: ["goblet_squat"],
            progressions: [],
            regressions: ["bodyweight_squat"],
            demoVideos: [],
            imageUrl: nil,
            tags: ["compound"]
        )
    }

    private static func fallbackRomanianDeadlift() -> Exercise {
        Exercise(
            id: "romanian_deadlift",
            name: "Romanian Deadlift",
            slug: "romanian-deadlift",
            primaryMuscles: [.hamstrings, .glutes],
            secondaryMuscles: [.lowerBack],
            equipment: [.barbell],
            movementPattern: .hinge,
            difficulty: .intermediate,
            forceType: .pull,
            mechanics: .compound,
            instructions: ["Hinge at hips with soft knees.", "Lower bar along legs.", "Return by driving hips forward."],
            formCues: ["Keep spine neutral throughout."],
            commonMistakes: ["Rounding lower back."],
            contraindications: [],
            substitutions: ["dumbbell_rdl"],
            progressions: [],
            regressions: ["hip_hinge_drill"],
            demoVideos: [],
            imageUrl: nil,
            tags: ["compound"]
        )
    }

    private static func fallbackPullUp() -> Exercise {
        Exercise(
            id: "pull_up",
            name: "Pull-Up",
            slug: "pull-up",
            primaryMuscles: [.back, .biceps],
            secondaryMuscles: [.forearms],
            equipment: [.pullUpBar],
            movementPattern: .verticalPull,
            difficulty: .intermediate,
            forceType: .pull,
            mechanics: .compound,
            instructions: ["Hang from bar.", "Pull chest toward bar.", "Lower under control."],
            formCues: ["Keep ribs down and avoid swinging."],
            commonMistakes: ["Kipping through reps."],
            contraindications: [],
            substitutions: ["lat_pulldown"],
            progressions: [],
            regressions: ["assisted_pull_up"],
            demoVideos: [],
            imageUrl: nil,
            tags: ["compound"]
        )
    }

    private static func fallbackDumbbellShoulderPress() -> Exercise {
        Exercise(
            id: "dumbbell_shoulder_press",
            name: "Dumbbell Shoulder Press",
            slug: "dumbbell-shoulder-press",
            primaryMuscles: [.shoulders],
            secondaryMuscles: [.triceps],
            equipment: [.dumbbell],
            movementPattern: .verticalPush,
            difficulty: .beginner,
            forceType: .push,
            mechanics: .compound,
            instructions: ["Press dumbbells overhead.", "Lower to shoulder line.", "Repeat with control."],
            formCues: ["Stack wrists over elbows."],
            commonMistakes: ["Overarching lower back."],
            contraindications: [],
            substitutions: ["seated_machine_press"],
            progressions: [],
            regressions: ["single_arm_press"],
            demoVideos: [],
            imageUrl: nil,
            tags: ["compound"]
        )
    }

    private static func fallbackCableRow() -> Exercise {
        Exercise(
            id: "cable_row",
            name: "Cable Row",
            slug: "cable-row",
            primaryMuscles: [.back],
            secondaryMuscles: [.biceps],
            equipment: [.cable],
            movementPattern: .horizontalPull,
            difficulty: .beginner,
            forceType: .pull,
            mechanics: .compound,
            instructions: ["Pull handle to torso.", "Pause with shoulder blades squeezed.", "Return slowly."],
            formCues: ["Lead with elbows, not hands."],
            commonMistakes: ["Shrugging shoulders up."],
            contraindications: [],
            substitutions: ["chest_supported_row"],
            progressions: [],
            regressions: ["band_row"],
            demoVideos: [],
            imageUrl: nil,
            tags: ["compound"]
        )
    }
}

private struct ExerciseSeedDTO: Decodable {
    let id: String
    let name: String
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]
    let equipment: [Equipment]
    let loadTrackingMode: LoadTrackingMode?
    let movementPattern: MovementPattern
    let difficulty: ExerciseDifficulty
    let mechanics: MechanicsType?
    let instructions: [String]
    let formCues: [String]
    let commonMistakes: [String]
    let substitutions: [String]
    let demoVideos: [ExerciseDemoVideo]

    func toExercise() -> Exercise {
        Exercise(
            id: id,
            name: name,
            slug: id.replacingOccurrences(of: "_", with: "-"),
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles,
            equipment: equipment,
            movementPattern: movementPattern,
            difficulty: difficulty,
            forceType: nil,
            mechanics: mechanics ?? movementPattern.inferredMechanics,
            instructions: instructions,
            formCues: formCues,
            commonMistakes: commonMistakes,
            contraindications: [],
            substitutions: substitutions,
            progressions: [],
            regressions: [],
            loadTrackingMode: loadTrackingMode,
            demoVideos: demoVideos,
            imageUrl: nil,
            tags: []
        )
    }
}

enum ExerciseFilter {
    static func apply(exercises: [Exercise], query: String, filters: ExerciseFilters) -> [Exercise] {
        var result = exercises

        if filters.excludeAvoided {
            result = result.filter { !$0.isAvoided }
        }
        if filters.favoritesOnly {
            result = result.filter(\.isFavorite)
        }
        if let muscle = filters.muscleGroup {
            result = result.filter { $0.primaryMuscles.contains(muscle) || $0.secondaryMuscles.contains(muscle) }
        }
        if let equipment = filters.equipment {
            result = result.filter { $0.equipment.contains(equipment) }
        }
        if let pattern = filters.movementPattern {
            result = result.filter { $0.movementPattern == pattern }
        }
        if let difficulty = filters.difficulty {
            result = result.filter { $0.difficulty == difficulty }
        }
        if !query.isEmpty {
            let q = query.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(q) ||
                $0.primaryMuscles.contains { $0.rawValue.contains(q) } ||
                $0.equipment.contains { $0.rawValue.contains(q) }
            }
        }
        return result.sorted { $0.name < $1.name }
    }
}

actor LocalExerciseMediaProvider: ExerciseMediaProvider {
    private let exerciseRepository: any ExerciseRepository

    init(exerciseRepository: any ExerciseRepository = LocalExerciseRepository()) {
        self.exerciseRepository = exerciseRepository
    }

    func demoVideos(for exerciseId: String) async throws -> [ExerciseDemoVideo] {
        if let exercise = try await exerciseRepository.fetch(id: exerciseId), !exercise.demoVideos.isEmpty {
            return exercise.demoVideos
        }
        if let fallback = ExerciseMediaResolver.bundledFallback(for: exerciseId) {
            return [fallback]
        }
        return []
    }
}

struct MockFoodSearchService: FoodSearchService, Sendable {
    func searchFoods(query: String) async throws -> [FoodSearchResult] {
        guard !query.isEmpty else { return [] }
        return [
            FoodSearchResult(id: "chicken_breast", name: "Chicken Breast", brand: nil, proteinPer100g: 31),
            FoodSearchResult(id: "greek_yogurt", name: "Greek Yogurt", brand: nil, proteinPer100g: 10),
            FoodSearchResult(id: "whey_protein", name: "Whey Protein Shake", brand: nil, proteinPer100g: 80)
        ].filter { $0.name.lowercased().contains(query.lowercased()) || query.count < 3 }
    }

    func getFoodDetails(id: String) async throws -> FoodNutritionDetails {
        FoodNutritionDetails(id: id, name: id.replacingOccurrences(of: "_", with: " ").capitalized, proteinGrams: 25, calories: 120, servingSize: "100g")
    }
}

struct MockBodyPhotoAnalyzer: BodyPhotoAnalyzer, Sendable {
    func analyze(photo: BodyProgressPhoto, previous: BodyProgressPhoto?) async throws -> BodyPhotoAnalysis {
        let ratio = 1.35
        let comparisonSummary = BodyPhotoVisionMetrics.comparisonSummary(
            currentRatio: ratio,
            previousRatio: previous?.analysis?.shoulderWaistRatio,
            hasPrevious: previous != nil
        )
        return BodyPhotoAnalysis(
            poseConfidence: 0.82,
            lightingScore: 0.75,
            framingScore: 0.88,
            shoulderWidthEstimate: 0.42,
            waistWidthEstimate: 0.31,
            hipWidthEstimate: 0.35,
            shoulderWaistRatio: ratio,
            postureNotes: ["Shoulders appear level.", "Consistent framing with prior session."],
            comparisonSummary: comparisonSummary,
            limitations: BodyPhotoVisionMetrics.limitations
        )
    }
}
