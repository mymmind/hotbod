import Foundation

actor LocalWorkoutRepository: WorkoutRepository {
    private let sessionsKey = "workout_sessions.json"
    private let todayKey = "today_workout.json"

    func fetchSessions() async throws -> [WorkoutSession] {
        PersistenceHelper.load([WorkoutSession].self, from: sessionsKey) ?? []
    }

    func saveSession(_ session: WorkoutSession) async throws {
        var sessions = try await fetchSessions()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        PersistenceHelper.save(sessions, to: sessionsKey)
    }

    func fetchTodayWorkout() async throws -> GeneratedWorkout? {
        PersistenceHelper.load(GeneratedWorkout.self, from: todayKey)
    }

    func saveTodayWorkout(_ workout: GeneratedWorkout) async throws {
        PersistenceHelper.save(workout, to: todayKey)
    }

    func clearTodayWorkout() async throws {
        PersistenceHelper.remove(todayKey)
    }

    func fetchSessionSummaries() async throws -> [WorkoutSessionSummary] {
        let sessions = try await fetchSessions().filter { $0.status == .completed }
        let exerciseMap = ExerciseCatalog.indexedById(ExerciseSeedLoader.load())

        return sessions.compactMap { session in
            guard let completedAt = session.completedAt else { return nil }
            let volume = session.exercises.flatMap(\.completedSets).reduce(0.0) { partial, set in
                partial + (set.weightKg ?? 0) * Double(set.reps)
            }
            var muscles = Set<MuscleGroup>()
            for we in session.exercises where !we.wasSkipped {
                if let exercise = exerciseMap[we.exerciseId] {
                    muscles.formUnion(exercise.primaryMuscles)
                }
            }
            let duration = session.startedAt.map { Int(completedAt.timeIntervalSince($0) / 60) } ?? session.estimatedDurationMinutes
            return WorkoutSessionSummary(
                id: session.id,
                title: session.title,
                completedAt: completedAt,
                totalVolumeKg: volume,
                totalSets: session.exercises.flatMap(\.completedSets).count,
                durationMinutes: duration,
                muscleGroups: Array(muscles)
            )
        }
    }
}

actor LocalNutritionRepository: NutritionRepository {
    private let key = "protein_entries.json"

    func fetchEntries(for date: Date) async throws -> [ProteinEntry] {
        let calendar = Calendar.current
        return try await fetchEntries(from: calendar.startOfDay(for: date), to: calendar.startOfNextDay(after: date))
    }

    func fetchEntries(from start: Date, to end: Date) async throws -> [ProteinEntry] {
        let all = PersistenceHelper.load([ProteinEntry].self, from: key) ?? []
        return all.filter { $0.date >= start && $0.date < end }
    }

    func saveEntry(_ entry: ProteinEntry) async throws {
        var entries = PersistenceHelper.load([ProteinEntry].self, from: key) ?? []
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        PersistenceHelper.save(entries, to: key)
    }

    func deleteEntry(id: UUID) async throws {
        var entries = PersistenceHelper.load([ProteinEntry].self, from: key) ?? []
        entries.removeAll { $0.id == id }
        PersistenceHelper.save(entries, to: key)
    }
}

actor LocalBodyProgressRepository: BodyProgressRepository {
    private let key = "body_photos.json"
    nonisolated let photosDirectory: URL

    init() {
        let dir = PersistenceHelper.appSupportURL.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        photosDirectory = dir
    }

    func fetchPhotos() async throws -> [BodyProgressPhoto] {
        PersistenceHelper.load([BodyProgressPhoto].self, from: key) ?? []
    }

    func savePhoto(_ photo: BodyProgressPhoto) async throws {
        var photos = try await fetchPhotos()
        if let index = photos.firstIndex(where: { $0.id == photo.id }) {
            photos[index] = photo
        } else {
            photos.append(photo)
        }
        PersistenceHelper.save(photos, to: key)
    }

    func deletePhoto(id: UUID) async throws {
        let photos = try await fetchPhotos()
        guard let photo = photos.first(where: { $0.id == id }) else { return }
        if FileManager.default.fileExists(atPath: photo.localImagePath) {
            try FileManager.default.removeItem(atPath: photo.localImagePath)
        }
        var remaining = photos
        remaining.removeAll { $0.id == id }
        PersistenceHelper.save(remaining, to: key)
    }
}

actor LocalUserProfileRepository: UserProfileRepository {
    private let profileKey = "user_profile.json"
    private let onboardingKey = "onboarding_complete.json"

    func fetchProfile() async throws -> UserProfile? {
        PersistenceHelper.load(UserProfile.self, from: profileKey)
    }

    func saveProfile(_ profile: UserProfile) async throws {
        PersistenceHelper.save(profile, to: profileKey)
    }

    func isOnboardingComplete() async throws -> Bool {
        PersistenceHelper.load(Bool.self, from: onboardingKey) ?? false
    }

    func setOnboardingComplete(_ complete: Bool) async throws {
        PersistenceHelper.save(complete, to: onboardingKey)
    }
}

actor LocalProgramStateRepository: ProgramStateRepository {
    private let key = "training_program_state.json"

    func fetchState() async throws -> TrainingProgramState {
        PersistenceHelper.load(TrainingProgramState.self, from: key) ?? TrainingProgramState()
    }

    func saveState(_ state: TrainingProgramState) async throws {
        PersistenceHelper.save(state, to: key)
    }
}

actor LocalRecoveryRepository: RecoveryRepository {
    private let key = "recovery_states.json"

    func fetchRecoveryStates() async throws -> [MuscleRecoveryState] {
        let loaded = PersistenceHelper.load([MuscleRecoveryState].self, from: key) ?? RecoveryCalculator.defaultStates()
        return RecoveryCalculator.normalizeStates(loaded)
    }

    func saveRecoveryStates(_ states: [MuscleRecoveryState]) async throws {
        PersistenceHelper.save(states, to: key)
    }
}

actor LocalExerciseStatsRepository: ExerciseStatsRepository {
    private let key = "exercise_stats.json"

    func fetchStats() async throws -> [UserExerciseStats] {
        PersistenceHelper.load([UserExerciseStats].self, from: key) ?? []
    }

    func saveStats(_ stats: [UserExerciseStats]) async throws {
        PersistenceHelper.save(stats, to: key)
    }
}

actor LocalCoachRepository: CoachRepository {
    private let key = "coach_messages.json"

    func fetchMessages() async throws -> [CoachMessage] {
        PersistenceHelper.load([CoachMessage].self, from: key) ?? []
    }

    func saveMessage(_ message: CoachMessage) async throws {
        var messages = try await fetchMessages()
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message
        } else {
            messages.append(message)
        }
        PersistenceHelper.save(messages, to: key)
    }
}
