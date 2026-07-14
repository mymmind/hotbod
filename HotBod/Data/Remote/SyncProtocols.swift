import Foundation

protocol AuthService: Sendable {
    var isAvailable: Bool { get }
    func currentUserId() async -> UUID?
    func currentEmail() async -> String?
    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func signOut() async throws
    func deleteAccount() async throws
    func restoreSession() async -> Bool
}

protocol CloudSyncService: Sendable {
    var isAvailable: Bool { get }
    func pullAll(local: SyncLocalStores) async throws
    func pushAll(local: SyncLocalStores) async throws
    func pushProfile(_ profile: UserProfile) async throws
    func pushTodayWorkout(_ workout: GeneratedWorkout) async throws
    func clearTodayWorkout() async throws
    func pushSession(_ session: WorkoutSession) async throws
    func pushProteinEntry(_ entry: ProteinEntry) async throws
    func pushPhoto(_ photo: BodyProgressPhoto, fileData: Data?) async throws
    func pushRecoveryStates(_ states: [MuscleRecoveryState]) async throws
    func pushExerciseStats(_ stats: [UserExerciseStats]) async throws
    func pushProgramState(_ state: TrainingProgramState) async throws
    func fetchPhotoBackupEnabled() async throws -> Bool
    func setPhotoBackupEnabled(_ enabled: Bool) async throws
}

struct SyncLocalStores {
    let userProfile: any UserProfileRepository
    let workout: any WorkoutRepository
    let exercise: any ExerciseRepository
    let nutrition: any NutritionRepository
    let bodyProgress: any BodyProgressRepository
    let recovery: any RecoveryRepository
    let exerciseStats: any ExerciseStatsRepository
    let coach: any CoachRepository
    let programState: any ProgramStateRepository
}

enum SyncError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case remote(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Supabase is not configured."
        case .notAuthenticated: "Sign in required for cloud sync."
        case .remote(let msg): msg
        }
    }
}
