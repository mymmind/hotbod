import Foundation

struct NoOpAuthService: AuthService, Sendable {
    var isAvailable: Bool { false }
    func currentUserId() async -> UUID? { nil }
    func currentEmail() async -> String? { nil }
    func signUp(email: String, password: String) async throws { throw SyncError.notConfigured }
    func signIn(email: String, password: String) async throws { throw SyncError.notConfigured }
    func signOut() async throws {}
    func deleteAccount() async throws { throw SyncError.notConfigured }
    func restoreSession() async -> Bool { false }
}

struct NoOpCloudSyncService: CloudSyncService, Sendable {
    var isAvailable: Bool { false }
    func pullAll(local: SyncLocalStores) async throws { throw SyncError.notConfigured }
    func pushAll(local: SyncLocalStores) async throws { throw SyncError.notConfigured }
    func pushProfile(_ profile: UserProfile) async throws { throw SyncError.notConfigured }
    func pushTodayWorkout(_ workout: GeneratedWorkout) async throws { throw SyncError.notConfigured }
    func clearTodayWorkout() async throws { throw SyncError.notConfigured }
    func pushSession(_ session: WorkoutSession) async throws { throw SyncError.notConfigured }
    func pushProteinEntry(_ entry: ProteinEntry) async throws { throw SyncError.notConfigured }
    func pushPhoto(_ photo: BodyProgressPhoto, fileData: Data?) async throws { throw SyncError.notConfigured }
    func pushRecoveryStates(_ states: [MuscleRecoveryState]) async throws { throw SyncError.notConfigured }
    func pushExerciseStats(_ stats: [UserExerciseStats]) async throws { throw SyncError.notConfigured }
    func pushProgramState(_ state: TrainingProgramState) async throws { throw SyncError.notConfigured }
    func fetchPhotoBackupEnabled() async throws -> Bool { false }
    func setPhotoBackupEnabled(_ enabled: Bool) async throws { throw SyncError.notConfigured }
}

/// Wires cloud auth, sync, and AI coach. Daily workout generation stays on
/// RulesWorkoutGenerationService — the coach proposes; validation gates apply.
enum BackendServices {
    static func makeAuthService() -> AuthService {
        #if canImport(Supabase)
        if let client = SupabaseClientProvider.shared {
            return SupabaseAuthService(client: client)
        }
        #endif
        return NoOpAuthService()
    }

    static func makeCloudSyncService(auth: AuthService) -> CloudSyncService {
        #if canImport(Supabase)
        if let client = SupabaseClientProvider.shared {
            return SupabaseCloudSyncService(client: client, auth: auth)
        }
        #endif
        return NoOpCloudSyncService()
    }

    static func makeAIWorkoutService(
        auth: AuthService,
        exerciseRepository: any ExerciseRepository = LocalExerciseRepository()
    ) -> AIWorkoutService {
        #if canImport(Supabase)
        if SupabaseConfig.isConfigured, let client = SupabaseClientProvider.shared {
            return RemoteAIWorkoutService(client: client, auth: auth)
        }
        #endif

        if GeminiConfig.isConfigured {
            return GeminiAIWorkoutService(exerciseRepository: exerciseRepository)
        }

        return MockAIWorkoutService()
    }

    static func makeFoodSearchService() -> FoodSearchService {
        if FoodAPIConfig.isConfigured {
            return USDAFoodSearchService()
        }
        return MockFoodSearchService()
    }
}
