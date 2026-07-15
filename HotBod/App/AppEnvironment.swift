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
    let healthKitWorkoutExportService: any HealthKitWorkoutExportService
    let stravaIntegrationService: any StravaIntegrationService
    let authService: any AuthService
    let cloudSyncService: any CloudSyncService
    let feedbackService: ForgeFeedbackService
    let subscriptionService: ForgeSubscriptionService

    var userProfile: UserProfile?
    var todayWorkout: GeneratedWorkout?
    var programState: TrainingProgramState = TrainingProgramState()
    var recoveryStates: [MuscleRecoveryState] = []
    var hasCompletedOnboarding: Bool = false
    var sorenessLevel: SorenessLevel = .none
    var lastValidation: WorkoutValidationResult?
    var lastGenerationFailure: GenerationFailure?
    var isSignedIn = false
    var authEmail: String?
    var syncMessage: String?
    var coachWorkoutUpdateMessage: String?
    var photoCloudBackupEnabled = false
    var isSupabaseConfigured = SupabaseConfig.isConfigured
    var healthReadiness: HealthReadinessSnapshot = .empty
    var isFoodAPIConfigured = FoodAPIConfig.isConfigured
    var paywallFeature: ProFeature?
    var bodyPhotoRevision = 0
    var onboardingViewModel = OnboardingViewModel()

    var sessionSaveTask: Task<Void, Never>?
    var pendingSessionSave: WorkoutSession?
    var sessionSaveGeneration: UInt = 0
    var workoutGenerationToken: UInt = 0
    var isWorkoutGenerationActive = false
    var isReservingWorkoutGeneration = false
    var isStartingWorkoutSession = false
    private(set) var isBootstrapping = false
    var hasCompletedBootstrap = false
    var calendarDayRevision = 0
    var dayScopedRefreshInProgress = false
    var dayScopedRefreshTask: Task<Void, Never>?

    var isWorkoutGenerationInFlight: Bool {
        isWorkoutGenerationActive
    }

    var isWorkoutGenerationReserved: Bool {
        isReservingWorkoutGeneration
    }

    var syncStores: SyncLocalStores {
        SyncLocalStores(
            userProfile: userProfileRepository,
            workout: workoutRepository,
            exercise: exerciseRepository,
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
        healthKitWorkoutExportService: (any HealthKitWorkoutExportService)? = nil,
        stravaIntegrationService: (any StravaIntegrationService)? = nil,
        authService: (any AuthService)? = nil,
        cloudSyncService: (any CloudSyncService)? = nil,
        feedbackService: ForgeFeedbackService = ForgeFeedbackService(),
        subscriptionService: ForgeSubscriptionService = ForgeSubscriptionService()
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
        self.healthKitWorkoutExportService = healthKitWorkoutExportService ?? HealthKitWorkoutExportServiceFactory.makeDefault()
        self.stravaIntegrationService = stravaIntegrationService ?? StravaIntegrationServiceFactory.makeDefault()
        self.cloudSyncService = cloudSyncService ?? BackendServices.makeCloudSyncService(auth: auth)
        self.feedbackService = feedbackService
        self.subscriptionService = subscriptionService
    }

    func bootstrap() async {
        isBootstrapping = true
        defer {
            isBootstrapping = false
            hasCompletedBootstrap = true
        }

        if UITestConfiguration.isUITesting, UITestConfiguration.shouldSkipOnboarding {
            let profile = UITestConfiguration.defaultOnboardedProfile()
            try? await userProfileRepository.saveProfile(profile)
            try? await userProfileRepository.setOnboardingComplete(true)
            userProfile = profile
            hasCompletedOnboarding = true
            recoveryStates = RecoveryCalculator.defaultStates()
            try? await recoveryRepository.saveRecoveryStates(recoveryStates)
            if TrainingSchedule.isTrainingDay(profile: profile),
               !UITestConfiguration.shouldStartWorkout,
               !UITestConfiguration.shouldOpenWorkoutPreview {
                await ensureTodayWorkoutOnLaunch(profile: profile)
            }
            return
        }

        hasCompletedOnboarding = (try? await userProfileRepository.isOnboardingComplete()) ?? false
        userProfile = try? await userProfileRepository.fetchProfile()
        todayWorkout = try? await workoutRepository.fetchTodayWorkout()
        programState = (try? await programStateRepository.fetchState()) ?? TrainingProgramState()
        recoveryStates = RecoveryCalculator.normalizeStates(
            (try? await recoveryRepository.fetchRecoveryStates()) ?? RecoveryCalculator.defaultStates()
        )
        let normalizedRecovery = recoveryStates
        try? await recoveryRepository.saveRecoveryStates(normalizedRecovery)

        let localDecayReference = programState.lastRecoveryDecayAppliedAt
        await refreshHealthReadiness()

        if authService.isAvailable, await authService.restoreSession() {
            isSignedIn = true
            authEmail = await authService.currentEmail()
            photoCloudBackupEnabled = (try? await cloudSyncService.fetchPhotoBackupEnabled()) ?? false
            await pullFromCloud()
            await mergeDecayReferenceAfterCloudPull(local: localDecayReference)
            recoveryStates = RecoveryCalculator.normalizeStates(
                (try? await recoveryRepository.fetchRecoveryStates()) ?? recoveryStates
            )
        }

        await repairPersistedCatalogReferences()
        await applyRecoveryDecay()
        await persistRegenerationWeekRefreshIfNeeded()
        await subscriptionService.bootstrap()

        await revalidateTodayPlanForCurrentDay()
    }

    /// Re-validates today's plan for the current calendar day: clears stale completion
    /// markers and regenerates (or clears) a plan generated on a previous day. Called
    /// from bootstrap and on foreground resume — bootstrap alone is not enough because
    /// iOS usually resumes the app from background instead of relaunching it.
    func revalidateTodayPlanForCurrentDay() async {
        guard hasCompletedOnboarding, let profile = userProfile else { return }
        await normalizeProgramStateForToday(profile: profile)
        let generationBlocked = isWorkoutGenerationInFlight
            || isWorkoutGenerationReserved
            || isStartingWorkoutSession
        let now = Date()
        let calendar = Calendar.current
        if TrainingSchedule.isTrainingDay(profile: profile) {
            if todayWorkout == nil, !isTodayWorkoutCompleted, !generationBlocked {
                await ensureTodayWorkoutOnLaunch(profile: profile)
            } else if let workout = todayWorkout,
                      !generationBlocked,
                      await shouldRegenerateStaleTodayWorkout(workout, now: now, calendar: calendar),
                      !isTodayWorkoutCompleted {
                await ensureTodayWorkoutOnLaunch(profile: profile)
            }
        } else if let workout = todayWorkout,
                  !generationBlocked,
                  await shouldRegenerateStaleTodayWorkout(workout, now: now, calendar: calendar) {
            await clearTodayWorkout()
        }
    }

    func mergeDecayReferenceAfterCloudPull(local: Date?) async {
        guard let local else { return }
        let cloud = programState.lastRecoveryDecayAppliedAt
        let merged = [local, cloud].compactMap { $0 }.max()
        guard merged != programState.lastRecoveryDecayAppliedAt else { return }
        var state = programState
        state.lastRecoveryDecayAppliedAt = merged
        programState = state
        try? await programStateRepository.saveState(state)
    }

    func clearTodayWorkout() async {
        todayWorkout = nil
        try? await workoutRepository.clearTodayWorkout()
        if isSignedIn {
            try? await cloudSyncService.clearTodayWorkout()
        }
    }

    func shouldRegenerateStaleTodayWorkout(
        _ workout: GeneratedWorkout,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async -> Bool {
        let sessions = (try? await workoutRepository.fetchSessions()) ?? []
        let hasActiveSession = activeWorkoutSession(in: sessions) != nil || isStartingWorkoutSession
        let hasCompletedSetsToday = sessions.contains {
            sessionHasCompletedSetsToday($0, now: now, calendar: calendar)
        }
        return WorkoutStaleness.shouldRegenerate(
            workoutCreatedAt: workout.createdAt,
            hasActiveSession: hasActiveSession,
            hasCompletedSetsToday: hasCompletedSetsToday,
            now: now,
            calendar: calendar
        )
    }

    func activeWorkoutSession(in sessions: [WorkoutSession]) -> WorkoutSession? {
        guard let id = programState.activeSessionId else { return nil }
        return sessions.first { $0.id == id && $0.status == .inProgress }
    }

    func hasCompletedSetsLoggedToday(now: Date = Date(), calendar: Calendar = .current) async -> Bool {
        let sessions = (try? await workoutRepository.fetchSessions()) ?? []
        return sessions.contains { session in
            sessionHasCompletedSetsToday(session, now: now, calendar: calendar)
        }
    }

    private func sessionHasCompletedSetsToday(
        _ session: WorkoutSession,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        session.exercises.flatMap(\.completedSets).contains {
            calendar.isDate($0.completedAt, inSameDayAs: now)
        }
    }

    func repairPersistedCatalogReferences() async {
        let exercises = (try? await exerciseRepository.fetchAll()) ?? []
        let catalogIds = Set(exercises.map(\.id))
        var workout = todayWorkout
        var stats = (try? await exerciseStatsRepository.fetchStats()) ?? []
        let result = CatalogIntegrity.sweep(catalogIds: catalogIds, workout: &workout, stats: &stats)

        if !result.flaggedOrphanStatIds.isEmpty {
            try? await exerciseStatsRepository.saveStats(stats)
        }

        if !result.removedWorkoutExerciseIds.isEmpty || result.workoutNeedsRegeneration {
            if let workout {
                todayWorkout = workout
                try? await workoutRepository.saveTodayWorkout(workout)
            } else {
                await clearTodayWorkout()
            }
        } else {
            todayWorkout = workout
        }
    }

    func blocksCoachWorkoutModification() async -> Bool {
        if await fetchActiveWorkoutSession() != nil { return true }
        return await hasCompletedSetsLoggedToday()
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
