import Foundation
import Observation

@Observable
@MainActor
final class AppEnvironment {
    // Architecture: RulesWorkoutGenerationService owns the daily plan (bootstrap + regenerate).
    // Cloud coach (RemoteAIWorkoutService + Supabase edge) proposes changes; server + client
    // validation gate every apply. Safe modifyWorkout proposals auto-apply; generateWorkout and
    // failed validation keep the manual Apply flow. HealthKit sleep/resting HR inform readiness hints.

    let workoutRepository: any WorkoutRepository
    let exerciseRepository: any ExerciseRepository
    let nutritionRepository: any NutritionRepository
    let bodyProgressRepository: any BodyProgressRepository
    let userProfileRepository: any UserProfileRepository
    let recoveryRepository: any RecoveryRepository
    let exerciseStatsRepository: any ExerciseStatsRepository
    let programStateRepository: any ProgramStateRepository
    let coachRepository: any CoachRepository
    let workoutGenerationService: any WorkoutGenerationService
    let aiWorkoutService: any AIWorkoutService
    let foodSearchService: any FoodSearchService
    let exerciseMediaProvider: any ExerciseMediaProvider
    let bodyPhotoAnalyzer: any BodyPhotoAnalyzer
    let healthKitReadinessService: any HealthKitReadinessService
    let authService: any AuthService
    let cloudSyncService: any CloudSyncService

    var userProfile: UserProfile?
    var todayWorkout: GeneratedWorkout?
    var programState: TrainingProgramState = TrainingProgramState()
    var recoveryStates: [MuscleRecoveryState] = []
    var hasCompletedOnboarding: Bool = false
    var sorenessLevel: SorenessLevel = .none
    var lastValidation: WorkoutValidationResult?
    var isSignedIn = false
    var authEmail: String?
    var syncMessage: String?
    var coachWorkoutUpdateMessage: String?
    var photoCloudBackupEnabled = false
    var isSupabaseConfigured = SupabaseConfig.isConfigured
    var healthReadiness: HealthReadinessSnapshot = .empty
    var isFoodAPIConfigured = FoodAPIConfig.isConfigured

    var sessionSaveTask: Task<Void, Never>?

    var syncStores: SyncLocalStores {
        SyncLocalStores(
            userProfile: userProfileRepository,
            workout: workoutRepository,
            nutrition: nutritionRepository,
            bodyProgress: bodyProgressRepository,
            recovery: recoveryRepository,
            exerciseStats: exerciseStatsRepository,
            coach: coachRepository,
            programState: programStateRepository
        )
    }

    init(
        workoutRepository: any WorkoutRepository = LocalWorkoutRepository(),
        exerciseRepository: any ExerciseRepository = LocalExerciseRepository(),
        nutritionRepository: any NutritionRepository = LocalNutritionRepository(),
        bodyProgressRepository: any BodyProgressRepository = LocalBodyProgressRepository(),
        userProfileRepository: any UserProfileRepository = LocalUserProfileRepository(),
        recoveryRepository: any RecoveryRepository = LocalRecoveryRepository(),
        exerciseStatsRepository: any ExerciseStatsRepository = LocalExerciseStatsRepository(),
        programStateRepository: any ProgramStateRepository = LocalProgramStateRepository(),
        coachRepository: any CoachRepository = LocalCoachRepository(),
        workoutGenerationService: any WorkoutGenerationService = RulesWorkoutGenerationService(),
        aiWorkoutService: (any AIWorkoutService)? = nil,
        foodSearchService: (any FoodSearchService)? = nil,
        exerciseMediaProvider: any ExerciseMediaProvider = LocalExerciseMediaProvider(),
        bodyPhotoAnalyzer: any BodyPhotoAnalyzer = VisionBodyPhotoAnalyzer(),
        healthKitReadinessService: (any HealthKitReadinessService)? = nil,
        authService: (any AuthService)? = nil,
        cloudSyncService: (any CloudSyncService)? = nil
    ) {
        self.workoutRepository = workoutRepository
        self.exerciseRepository = exerciseRepository
        self.nutritionRepository = nutritionRepository
        self.bodyProgressRepository = bodyProgressRepository
        self.userProfileRepository = userProfileRepository
        self.recoveryRepository = recoveryRepository
        self.exerciseStatsRepository = exerciseStatsRepository
        self.programStateRepository = programStateRepository
        self.coachRepository = coachRepository
        self.workoutGenerationService = workoutGenerationService
        let auth = authService ?? BackendServices.makeAuthService()
        self.authService = auth
        self.aiWorkoutService = aiWorkoutService ?? BackendServices.makeAIWorkoutService(auth: auth, exerciseRepository: exerciseRepository)
        self.foodSearchService = foodSearchService ?? BackendServices.makeFoodSearchService()
        self.exerciseMediaProvider = exerciseMediaProvider
        self.bodyPhotoAnalyzer = bodyPhotoAnalyzer
        self.healthKitReadinessService = healthKitReadinessService ?? HealthKitReadinessServiceFactory.makeDefault()
        self.cloudSyncService = cloudSyncService ?? BackendServices.makeCloudSyncService(auth: auth)
    }

    func bootstrap() async {
        hasCompletedOnboarding = (try? await userProfileRepository.isOnboardingComplete()) ?? false
        userProfile = try? await userProfileRepository.fetchProfile()
        todayWorkout = try? await workoutRepository.fetchTodayWorkout()
        programState = (try? await programStateRepository.fetchState()) ?? TrainingProgramState()
        recoveryStates = (try? await recoveryRepository.fetchRecoveryStates()) ?? RecoveryCalculator.defaultStates()
        await applyRecoveryDecay()
        await refreshHealthReadiness()

        if authService.isAvailable, await authService.restoreSession() {
            isSignedIn = true
            authEmail = await authService.currentEmail()
            photoCloudBackupEnabled = (try? await cloudSyncService.fetchPhotoBackupEnabled()) ?? false
            await pullFromCloud()
        }

        if hasCompletedOnboarding, let profile = userProfile {
            await normalizeProgramStateForToday(profile: profile)
            if TrainingSchedule.isTrainingDay(profile: profile) {
                if todayWorkout == nil, !isTodayWorkoutCompleted {
                    await regenerateTodayWorkout(profile: profile)
                } else if let workout = todayWorkout,
                          !Calendar.current.isDateInToday(workout.createdAt),
                          !isTodayWorkoutCompleted {
                    await regenerateTodayWorkout(profile: profile)
                }
            } else if !TrainingSchedule.isTrainingDay(profile: profile),
                      let workout = todayWorkout,
                      !Calendar.current.isDateInToday(workout.createdAt) {
                todayWorkout = nil
            }
        }
    }

    var isRestDay: Bool {
        guard let profile = userProfile else { return false }
        return !TrainingSchedule.isTrainingDay(profile: profile)
    }

    var isTodayWorkoutCompleted: Bool {
        TrainingSchedule.isTodayWorkoutCompleted(state: programState)
    }

    var currentSplitFocus: SplitDayFocus? {
        guard let profile = userProfile else { return nil }
        return TrainingSchedule.currentSplitFocus(state: programState, split: profile.preferredSplit)
    }
}
