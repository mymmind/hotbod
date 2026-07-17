import Foundation
@testable import HotBod

struct TestRepositories {
  var workout: InMemoryWorkoutRepository
  var exercise: InMemoryExerciseRepository
  var nutrition: InMemoryNutritionRepository
  var bodyProgress: InMemoryBodyProgressRepository
  var userProfile: InMemoryUserProfileRepository
  var recovery: InMemoryRecoveryRepository
  var exerciseStats: InMemoryExerciseStatsRepository
  var programState: InMemoryProgramStateRepository
  var coach: InMemoryCoachRepository

  static func withCatalog() -> TestRepositories {
    empty(exercises: ExerciseCatalogLoader.loadExercises())
  }

  static func empty(exercises: [Exercise] = []) -> TestRepositories {
    TestRepositories(
      workout: InMemoryWorkoutRepository(),
      exercise: InMemoryExerciseRepository(exercises: exercises),
      nutrition: InMemoryNutritionRepository(),
      bodyProgress: InMemoryBodyProgressRepository(),
      userProfile: InMemoryUserProfileRepository(),
      recovery: InMemoryRecoveryRepository(),
      exerciseStats: InMemoryExerciseStatsRepository(),
      programState: InMemoryProgramStateRepository(),
      coach: InMemoryCoachRepository()
    )
  }
}

actor InMemoryWorkoutRepository: WorkoutRepository {
  private var sessions: [WorkoutSession] = []
  private var todayWorkout: GeneratedWorkout?

  func fetchSessions() async throws -> [WorkoutSession] { sessions }
  func saveSession(_ session: WorkoutSession) async throws {
    if let index = sessions.firstIndex(where: { $0.id == session.id }) {
      sessions[index] = session
    } else {
      sessions.append(session)
    }
  }
  func fetchTodayWorkout() async throws -> GeneratedWorkout? { todayWorkout }
  func saveTodayWorkout(_ workout: GeneratedWorkout) async throws { todayWorkout = workout }
  func clearTodayWorkout() async throws { todayWorkout = nil }
  func fetchSessionSummaries() async throws -> [WorkoutSessionSummary] {
    sessions.compactMap { session in
      guard session.status == .completed, let completedAt = session.completedAt else { return nil }
      let volume = session.exercises.flatMap(\.completedSets).reduce(0.0) { $0 + ($1.weightKg ?? 0) * Double($1.reps) }
      return WorkoutSessionSummary(
        id: session.id,
        title: session.title,
        completedAt: completedAt,
        totalVolumeKg: volume,
        totalSets: session.exercises.flatMap(\.completedSets).count,
        durationMinutes: session.estimatedDurationMinutes,
        muscleGroups: []
      )
    }
  }
}

actor InMemoryExerciseRepository: ExerciseRepository {
  private var exercises: [Exercise]

  init(exercises: [Exercise] = []) {
    self.exercises = exercises
  }

  func fetchAll() async throws -> [Exercise] { exercises }
  func fetch(id: String) async throws -> Exercise? { exercises.first { $0.id == id } }
  func fetchSubstitutionGroups() async throws -> [ExerciseSubstitutionGroup] { [] }
  func fetchExercises(inGroup groupId: String) async throws -> [Exercise] { [] }
  func substitutionGroup(for exerciseId: String) async throws -> ExerciseSubstitutionGroup? { nil }
  func updateFavorite(id: String, isFavorite: Bool) async throws {
    guard let index = exercises.firstIndex(where: { $0.id == id }) else { return }
    exercises[index].preference = isFavorite ? .favorite : (exercises[index].preference == .favorite ? .neutral : exercises[index].preference)
  }
  func updateAvoided(id: String, isAvoided: Bool) async throws {
    guard let index = exercises.firstIndex(where: { $0.id == id }) else { return }
    let current = exercises[index].preference
    let next: ExercisePreference
    if isAvoided {
      next = .excluded
    } else if current == .excluded {
      next = .neutral
    } else {
      next = current
    }
    exercises[index].preference = next
  }
  func updatePreference(id: String, preference: ExercisePreference) async throws {
    guard let index = exercises.firstIndex(where: { $0.id == id }) else { return }
    exercises[index].preference = preference
  }

  func resetUserPreferences() async throws {
    for index in exercises.indices {
      exercises[index].preference = .neutral
    }
  }

  func resetCustomExercises() async throws {
    exercises.removeAll { $0.isCustom }
    for index in exercises.indices {
      exercises[index].preference = .neutral
    }
  }

  func preferenceOverrides() async -> [String: ExercisePreference] {
    Dictionary(uniqueKeysWithValues: exercises.compactMap { exercise in
      exercise.preference == .neutral ? nil : (exercise.id, exercise.preference)
    })
  }

  func applyPreferenceOverrides(_ overrides: [String: ExercisePreference]) async throws {
    for index in exercises.indices {
      exercises[index].preference = overrides[exercises[index].id] ?? .neutral
    }
  }

  func createCustomExercise(_ exercise: Exercise) async throws -> Exercise {
    var custom = exercise
    custom.isCustom = true
    exercises.append(custom)
    return custom
  }

  func deleteCustomExercise(id: String) async throws {
    exercises.removeAll { $0.id == id && $0.isCustom }
  }
}

actor InMemoryNutritionRepository: NutritionRepository {
  private var entries: [ProteinEntry] = []

  func fetchEntries(for date: Date) async throws -> [ProteinEntry] {
    let calendar = Calendar.current
    return entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
  }

  func fetchEntries(from start: Date, to end: Date) async throws -> [ProteinEntry] {
    entries.filter { $0.date >= start && $0.date < end }
  }

  func saveEntry(_ entry: ProteinEntry) async throws {
    if let index = entries.firstIndex(where: { $0.id == entry.id }) {
      entries[index] = entry
    } else {
      entries.append(entry)
    }
  }

  func deleteEntry(id: UUID) async throws {
    entries.removeAll { $0.id == id }
  }
}

actor InMemoryBodyProgressRepository: BodyProgressRepository {
  private var photos: [BodyProgressPhoto] = []

  func fetchPhotos() async throws -> [BodyProgressPhoto] { photos }
  func savePhoto(_ photo: BodyProgressPhoto) async throws {
    if let index = photos.firstIndex(where: { $0.id == photo.id }) {
      photos[index] = photo
    } else {
      photos.append(photo)
    }
  }
  func deletePhoto(id: UUID) async throws {
    if let photo = photos.first(where: { $0.id == id }) {
      let fileURL = BodyPhotoPathResolver.resolve(photo.localImagePath)
      if FileManager.default.fileExists(atPath: fileURL.path) {
        try? FileManager.default.removeItem(at: fileURL)
      }
    }
    photos.removeAll { $0.id == id }
  }
}

actor InMemoryUserProfileRepository: UserProfileRepository {
  private var profile: UserProfile?
  private var onboardingComplete = false

  func fetchProfile() async throws -> UserProfile? { profile }
  func saveProfile(_ profile: UserProfile) async throws { self.profile = profile }
  func isOnboardingComplete() async throws -> Bool { onboardingComplete }
  func setOnboardingComplete(_ complete: Bool) async throws { onboardingComplete = complete }
}

actor InMemoryRecoveryRepository: RecoveryRepository {
  private var states: [MuscleRecoveryState] = RecoveryCalculator.defaultStates()

  func fetchRecoveryStates() async throws -> [MuscleRecoveryState] {
    RecoveryCalculator.normalizeStates(states)
  }

  func saveRecoveryStates(_ states: [MuscleRecoveryState]) async throws {
    self.states = states
  }
}

actor InMemoryExerciseStatsRepository: ExerciseStatsRepository {
  private var stats: [UserExerciseStats] = []

  func fetchStats() async throws -> [UserExerciseStats] { stats }
  func saveStats(_ stats: [UserExerciseStats]) async throws { self.stats = stats }
}

actor InMemoryProgramStateRepository: ProgramStateRepository {
  private var state = TrainingProgramState()

  func fetchState() async throws -> TrainingProgramState { state }
  func saveState(_ state: TrainingProgramState) async throws { self.state = state }
}

actor InMemoryCoachRepository: CoachRepository {
  private var messages: [CoachMessage] = []

  func fetchMessages() async throws -> [CoachMessage] { messages }
  func saveMessage(_ message: CoachMessage) async throws {
    if let index = messages.firstIndex(where: { $0.id == message.id }) {
      messages[index] = message
    } else {
      messages.append(message)
    }
  }
}

final class CountingCloudSyncService: CloudSyncService, @unchecked Sendable {
  private let noOp = NoOpCloudSyncService()
  private(set) var pullCount = 0
  var pullDelayNanoseconds: UInt64 = 50_000_000

  var isAvailable: Bool { true }

  func pullAll(local: SyncLocalStores) async throws {
    pullCount += 1
    try await Task.sleep(nanoseconds: pullDelayNanoseconds)
    try await noOp.pullAll(local: local)
  }

  func pushAll(local: SyncLocalStores) async throws { try await noOp.pushAll(local: local) }
  func pushProfile(_ profile: UserProfile) async throws { try await noOp.pushProfile(profile) }
  func pushTodayWorkout(_ workout: GeneratedWorkout) async throws { try await noOp.pushTodayWorkout(workout) }
  func clearTodayWorkout() async throws { try await noOp.clearTodayWorkout() }
  func pushSession(_ session: WorkoutSession) async throws { try await noOp.pushSession(session) }
  func pushProteinEntry(_ entry: ProteinEntry) async throws { try await noOp.pushProteinEntry(entry) }
  func pushPhoto(_ photo: BodyProgressPhoto, fileData: Data?) async throws {
    try await noOp.pushPhoto(photo, fileData: fileData)
  }
  func pushRecoveryStates(_ states: [MuscleRecoveryState]) async throws {
    try await noOp.pushRecoveryStates(states)
  }
  func pushExerciseStats(_ stats: [UserExerciseStats]) async throws {
    try await noOp.pushExerciseStats(stats)
  }
  func pushProgramState(_ state: TrainingProgramState) async throws {
    try await noOp.pushProgramState(state)
  }
  func fetchPhotoBackupEnabled() async throws -> Bool { try await noOp.fetchPhotoBackupEnabled() }
  func setPhotoBackupEnabled(_ enabled: Bool) async throws { try await noOp.setPhotoBackupEnabled(enabled) }
}

final class ProgramStatePullCloudSyncService: CloudSyncService, @unchecked Sendable {
  private let noOp = NoOpCloudSyncService()
  private let pulledProgramState: TrainingProgramState

  init(pulledProgramState: TrainingProgramState) {
    self.pulledProgramState = pulledProgramState
  }

  var isAvailable: Bool { true }

  func pullAll(local: SyncLocalStores) async throws {
    try await local.programState.saveState(pulledProgramState)
  }

  func pushAll(local: SyncLocalStores) async throws { try await noOp.pushAll(local: local) }
  func pushProfile(_ profile: UserProfile) async throws { try await noOp.pushProfile(profile) }
  func pushTodayWorkout(_ workout: GeneratedWorkout) async throws { try await noOp.pushTodayWorkout(workout) }
  func clearTodayWorkout() async throws { try await noOp.clearTodayWorkout() }
  func pushSession(_ session: WorkoutSession) async throws { try await noOp.pushSession(session) }
  func pushProteinEntry(_ entry: ProteinEntry) async throws { try await noOp.pushProteinEntry(entry) }
  func pushPhoto(_ photo: BodyProgressPhoto, fileData: Data?) async throws {
    try await noOp.pushPhoto(photo, fileData: fileData)
  }
  func pushRecoveryStates(_ states: [MuscleRecoveryState]) async throws {
    try await noOp.pushRecoveryStates(states)
  }
  func pushExerciseStats(_ stats: [UserExerciseStats]) async throws {
    try await noOp.pushExerciseStats(stats)
  }
  func pushProgramState(_ state: TrainingProgramState) async throws {
    try await noOp.pushProgramState(state)
  }
  func fetchPhotoBackupEnabled() async throws -> Bool { try await noOp.fetchPhotoBackupEnabled() }
  func setPhotoBackupEnabled(_ enabled: Bool) async throws { try await noOp.setPhotoBackupEnabled(enabled) }
}

actor FailingSaveWorkoutRepository: WorkoutRepository {
  private let wrapped: InMemoryWorkoutRepository
  var shouldFailSaveSession = true

  init(wrapped: InMemoryWorkoutRepository) {
    self.wrapped = wrapped
  }

  func fetchSessions() async throws -> [WorkoutSession] { try await wrapped.fetchSessions() }
  func saveSession(_ session: WorkoutSession) async throws {
    if shouldFailSaveSession {
      throw NSError(domain: "test", code: 1)
    }
    try await wrapped.saveSession(session)
  }
  func fetchTodayWorkout() async throws -> GeneratedWorkout? { try await wrapped.fetchTodayWorkout() }
  func saveTodayWorkout(_ workout: GeneratedWorkout) async throws { try await wrapped.saveTodayWorkout(workout) }
  func clearTodayWorkout() async throws { try await wrapped.clearTodayWorkout() }
  func fetchSessionSummaries() async throws -> [WorkoutSessionSummary] {
    try await wrapped.fetchSessionSummaries()
  }
}
