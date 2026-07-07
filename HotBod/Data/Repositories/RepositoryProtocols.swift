import Foundation

// MARK: - Repository Protocols

protocol WorkoutRepository: Sendable {
    func fetchSessions() async throws -> [WorkoutSession]
    func saveSession(_ session: WorkoutSession) async throws
    func fetchTodayWorkout() async throws -> GeneratedWorkout?
    func saveTodayWorkout(_ workout: GeneratedWorkout) async throws
    func fetchSessionSummaries() async throws -> [WorkoutSessionSummary]
}

protocol ExerciseRepository: Sendable {
    func fetchAll() async throws -> [Exercise]
    func fetch(id: String) async throws -> Exercise?
    func search(query: String, filters: ExerciseFilters) async throws -> [Exercise]
    func fetchSubstitutionGroups() async throws -> [ExerciseSubstitutionGroup]
    func fetchExercises(inGroup groupId: String) async throws -> [Exercise]
    func substitutionGroup(for exerciseId: String) async throws -> ExerciseSubstitutionGroup?
    func substitutes(
        for exerciseId: String,
        availableEquipment: [Equipment],
        injuries: [BodyLimitation],
        excludeIds: Set<String>
    ) async throws -> [Exercise]
    func updateFavorite(id: String, isFavorite: Bool) async throws
    func updateAvoided(id: String, isAvoided: Bool) async throws
}

struct ExerciseFilters: Hashable {
    var muscleGroup: MuscleGroup?
    var equipment: Equipment?
    var movementPattern: MovementPattern?
    var difficulty: ExerciseDifficulty?
    var favoritesOnly: Bool = false
    var excludeAvoided: Bool = true
}

protocol NutritionRepository: Sendable {
    func fetchEntries(for date: Date) async throws -> [ProteinEntry]
    func fetchEntries(from start: Date, to end: Date) async throws -> [ProteinEntry]
    func saveEntry(_ entry: ProteinEntry) async throws
    func deleteEntry(id: UUID) async throws
}

protocol BodyProgressRepository: Sendable {
    func fetchPhotos() async throws -> [BodyProgressPhoto]
    func savePhoto(_ photo: BodyProgressPhoto) async throws
    func deletePhoto(id: UUID) async throws
}

protocol UserProfileRepository: Sendable {
    func fetchProfile() async throws -> UserProfile?
    func saveProfile(_ profile: UserProfile) async throws
    func isOnboardingComplete() async throws -> Bool
    func setOnboardingComplete(_ complete: Bool) async throws
}

protocol ProgramStateRepository: Sendable {
    func fetchState() async throws -> TrainingProgramState
    func saveState(_ state: TrainingProgramState) async throws
}

protocol RecoveryRepository: Sendable {
    func fetchRecoveryStates() async throws -> [MuscleRecoveryState]
    func saveRecoveryStates(_ states: [MuscleRecoveryState]) async throws
}

protocol ExerciseStatsRepository: Sendable {
    func fetchStats() async throws -> [UserExerciseStats]
    func saveStats(_ stats: [UserExerciseStats]) async throws
}

protocol CoachRepository: Sendable {
    func fetchMessages() async throws -> [CoachMessage]
    func saveMessage(_ message: CoachMessage) async throws
}

// MARK: - Service Protocols

protocol AIWorkoutService: Sendable {
    func respond(to message: String, context: CoachContext) async throws -> CoachAIResult
    func classifyIntent(_ message: String) async -> CoachIntent
}

protocol FoodSearchService: Sendable {
    func searchFoods(query: String) async throws -> [FoodSearchResult]
    func getFoodDetails(id: String) async throws -> FoodNutritionDetails
}

protocol ExerciseMediaProvider: Sendable {
    func demoVideos(for exerciseId: String) async throws -> [ExerciseDemoVideo]
}

protocol BodyPhotoAnalyzer: Sendable {
    func analyze(photo: BodyProgressPhoto, previous: BodyProgressPhoto?) async throws -> BodyPhotoAnalysis
}

protocol HealthKitReadinessService: Sendable {
    var isAvailable: Bool { get }
    func requestAuthorizationIfNeeded() async
    func fetchReadinessSnapshot() async -> HealthReadinessSnapshot
}

protocol WorkoutGenerationService: Sendable {
    func generate(input: WorkoutGenerationInput) async throws -> GeneratedWorkout
    func validate(workout: GeneratedWorkout, input: WorkoutGenerationInput) -> WorkoutValidationResult
}
