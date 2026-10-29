import Foundation
@testable import HotBod

enum FixtureBuilders {
  static func makeWorkoutSession(
    exerciseId: String = "bench_press",
    status: WorkoutStatus = .inProgress
  ) -> WorkoutSession {
    WorkoutSession(
      userId: UUID(),
      title: "Test Session",
      startedAt: Date(),
      estimatedDurationMinutes: 45,
      exercises: [
        WorkoutExercise(
          exerciseId: exerciseId,
          orderIndex: 0,
          plannedSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 60)],
          restSeconds: 90
        )
      ],
      status: status,
      splitDayFocus: .push
    )
  }

  static func makeGeneratedWorkout(
    exerciseId: String = "bench_press",
    createdAt: Date = Date()
  ) -> GeneratedWorkout {
    GeneratedWorkout(
      id: UUID(),
      title: "Test Workout",
      estimatedDurationMinutes: 45,
      focus: [.chest],
      exercises: [
        PlannedExercise(
          exerciseId: exerciseId,
          orderIndex: 0,
          targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 60)]
        )
      ],
      rationale: "Test",
      safetyNotes: [],
      generatedBy: .rulesEngine,
      createdAt: createdAt
    )
  }

  static func makeProteinEntry(
    grams: Double,
    date: Date = Date(),
    foodName: String = "Chicken"
  ) -> ProteinEntry {
    ProteinEntry(
      id: UUID(),
      date: date,
      mealType: .lunch,
      foodName: foodName,
      servingDescription: "100g",
      proteinGrams: grams,
      calories: grams * 4,
      carbsGrams: 0,
      fatGrams: 0,
      source: .manual
    )
  }

  static func makeValidationInput(stats: [UserExerciseStats] = []) -> WorkoutGenerationInput {
    let profile = UserProfile.empty()
    return WorkoutGenerationInput(
      userProfile: profile,
      goal: profile.goal,
      experienceLevel: profile.experienceLevel,
      availableEquipment: profile.availableEquipment,
      targetDurationMinutes: 45,
      preferredMuscleGroups: [],
      avoidedMuscleGroups: [],
      injuries: [],
      recentWorkouts: [],
      muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 80.0) }),
      exerciseStats: stats,
      userPreferences: WorkoutPreferences(),
      readiness: ReadinessInput(soreness: .none),
      splitDayFocus: nil
    )
  }

  static func makeBodyPhoto(
    pose: BodyPhotoPoseType,
    userId: UUID = UUID(),
    analysis: BodyPhotoAnalysis? = BodyPhotoAnalysis(
      poseConfidence: 0.8,
      lightingScore: 0.8,
      framingScore: 0.8,
      shoulderWidthEstimate: nil,
      waistWidthEstimate: nil,
      hipWidthEstimate: nil,
      shoulderWaistRatio: nil,
      postureNotes: [],
      comparisonSummary: nil,
      limitations: []
    ),
    date: Date = Date()
  ) -> BodyProgressPhoto {
    var photo = BodyProgressPhoto(
      id: UUID(),
      userId: userId,
      date: date,
      poseType: pose,
      localImagePath: "/tmp/\(UUID().uuidString).jpg"
    )
    photo.analysis = analysis
    return photo
  }

  static func makePhysiqueAssessmentRequest(
    includeBack: Bool = true,
    includeSide: Bool = false,
    poorSideMetrics: Bool = false
  ) -> PhysiqueAssessmentRequest {
    let frontMetrics = BodyPhotoAnalysis(
      poseConfidence: 0.8,
      lightingScore: 0.75,
      framingScore: 0.8,
      shoulderWidthEstimate: 1.2,
      waistWidthEstimate: 0.9,
      hipWidthEstimate: 1.0,
      shoulderWaistRatio: 1.35,
      postureNotes: [],
      comparisonSummary: nil,
      limitations: []
    )
    let backMetrics: BodyPhotoAnalysis? = includeBack
      ? BodyPhotoAnalysis(
        poseConfidence: 0.78,
        lightingScore: 0.72,
        framingScore: 0.76,
        shoulderWidthEstimate: nil,
        waistWidthEstimate: nil,
        hipWidthEstimate: nil,
        shoulderWaistRatio: nil,
        postureNotes: [],
        comparisonSummary: nil,
        limitations: []
      )
      : nil
    let sideMetrics = includeSide
      ? BodyPhotoAnalysis(
        poseConfidence: poorSideMetrics ? 0.2 : 0.82,
        lightingScore: poorSideMetrics ? 0.2 : 0.74,
        framingScore: poorSideMetrics ? 0.2 : 0.78,
        shoulderWidthEstimate: nil,
        waistWidthEstimate: nil,
        hipWidthEstimate: nil,
        shoulderWaistRatio: nil,
        postureNotes: [],
        comparisonSummary: nil,
        limitations: []
      )
      : nil

    let front = makeBodyPhoto(pose: .frontRelaxed, analysis: frontMetrics)
    let back = backMetrics.map { makeBodyPhoto(pose: .backRelaxed, analysis: $0) }
    let side = sideMetrics.map { makeBodyPhoto(pose: .sideRelaxed, analysis: $0) }

    return PhysiqueAssessmentRequest(
      selection: PhysiquePhotoSelection(front: front, back: back, side: side),
      frontMetrics: frontMetrics,
      backMetrics: backMetrics,
      sideMetrics: sideMetrics,
      profile: UserProfile.empty()
    )
  }

  static func makePhysiqueAssessment(
    id: UUID = UUID(),
    createdAt: Date = Date(),
    frontPhotoId: UUID = UUID(),
    backPhotoId: UUID? = UUID(),
    sidePhotoId: UUID? = nil,
    physique: PhysiqueBuildSummary? = nil,
    developmentPriorities: [PhysiqueDevelopmentPriority]? = nil,
    physiqueDirections: [PhysiqueArchetypeMatch] = [],
    trendAdaptation: PhysiqueTrendAdaptation? = nil
  ) -> PhysiqueAssessment {
    let priorities = developmentPriorities ?? [
      PhysiqueDevelopmentPriority(
        muscle: .lateralDelts,
        reason: "Side delt width improves shoulder line."
      ),
      PhysiqueDevelopmentPriority(
        muscle: .lats,
        reason: "Lat width supports V-taper balance."
      ),
      PhysiqueDevelopmentPriority(
        muscle: .upperChest,
        reason: "Upper chest fills the clavicular line."
      )
    ]
    return PhysiqueAssessment(
      id: id,
      createdAt: createdAt,
      frontPhotoId: frontPhotoId,
      backPhotoId: backPhotoId,
      sidePhotoId: sidePhotoId,
      photoQuality: PhysiquePhotoQuality(
        anglesAvailable: ["front", "back"],
        lightingQuality: "Even",
        overallConfidence: 0.72
      ),
      physique: physique ?? PhysiqueBuildSummary(
        overallArchetype: "Athletic build with moderate shoulder-to-waist contrast",
        frameSize: "Medium",
        shoulderToWaist: "Moderate contrast",
        waist: "Defined",
        torso: "Balanced",
        muscularity: "Moderate",
        leanness: "Moderate"
      ),
      muscleEntries: [
        PhysiqueMuscleEntry(
          muscle: .lateralDelts,
          current: "Moderate side delt development",
          priorityRank: 1,
          notes: "Visible from front angle",
          confidence: .high
        )
      ],
      developmentPriorities: priorities,
      trainingBias: PhysiqueTrainingBias(
        preferredMuscleGroups: [.shoulders, .back, .chest],
        rationale: "Prioritize shoulder width, back width, and upper chest for frame balance."
      ),
      limitations: [
        "Visual estimate only — not a medical assessment.",
        "Side photo missing; rear detail may be less reliable."
      ],
      confidenceBands: PhysiqueConfidenceBands(
        high: ["Front shoulder line"],
        medium: ["Back lat spread"],
        low: ["Rear delt detail without side photo"]
      ),
      source: .onDevice,
      whyTodaySummary: "Bias shoulders, back, and chest to improve visual frame balance.",
      physiqueDirections: physiqueDirections,
      trendAdaptation: trendAdaptation
    )
  }

  static func makeValidWorkout(exerciseId: String, exercises: [Exercise]) -> GeneratedWorkout {
    GeneratedWorkout(
      id: UUID(),
      title: "Valid",
      estimatedDurationMinutes: 45,
      focus: exercises.first?.primaryMuscles ?? [.chest],
      exercises: [
        PlannedExercise(
          exerciseId: exerciseId,
          orderIndex: 0,
          targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 60)]
        )
      ],
      rationale: "",
      safetyNotes: [],
      generatedBy: .rulesEngine,
      createdAt: Date()
    )
  }
}

final class RecordingWorkoutReminderScheduler: WorkoutReminderScheduling, @unchecked Sendable {
  var alreadyTrainedFlags: [Bool] = []

  func requestAuthorizationIfNeeded() async -> Bool { true }

  func reschedule(profile: UserProfile, focusHint: String?, alreadyTrainedToday: Bool) async {
    alreadyTrainedFlags.append(alreadyTrainedToday)
  }

  func cancelAll() async {}
}

final class RecordingPhysiqueReassessReminderScheduler: PhysiqueReassessReminderScheduling, @unchecked Sendable {
  var rescheduleCalls: [(enabled: Bool, createdAt: Date?)] = []
  var cancelCount = 0

  func requestAuthorizationIfNeeded() async -> Bool { true }

  func reschedule(profile: UserProfile, assessmentCreatedAt: Date?) async {
    rescheduleCalls.append((profile.workoutRemindersEnabled, assessmentCreatedAt))
  }

  func cancelAll() async {
    cancelCount += 1
  }
}

@MainActor
extension AppEnvironment {
  static func makeForTests(
    repos: TestRepositories = .empty(),
    workoutGenerationService: (any WorkoutGenerationService)? = nil,
    aiWorkoutService: (any AIWorkoutService)? = nil,
    appleLanguageModeling: (any AppleLanguageModeling)? = nil,
    foodSearchService: (any FoodSearchService)? = nil,
    authService: (any AuthService)? = nil,
    cloudSyncService: (any CloudSyncService)? = nil,
    physiqueIllustrationService: (any PhysiqueIllustrationService)? = nil,
    physiqueIllustrationStore: LocalPhysiqueIllustrationStore? = nil,
    physiqueAssessmentService: HybridPhysiqueAssessmentService? = nil,
    physiqueReassessReminderScheduler: (any PhysiqueReassessReminderScheduling)? = nil,
    workoutReminderScheduler: (any WorkoutReminderScheduling)? = nil
  ) -> AppEnvironment {
    let analyzer = MockBodyPhotoAnalyzer()
    return AppEnvironment(
      repositories: AppEnvironmentRepositories(
        workout: repos.workout,
        exercise: repos.exercise,
        nutrition: repos.nutrition,
        bodyProgress: repos.bodyProgress,
        userProfile: repos.userProfile,
        recovery: repos.recovery,
        exerciseStats: repos.exerciseStats,
        programState: repos.programState,
        coach: repos.coach,
        physiqueAssessment: repos.physiqueAssessment
      ),
      workoutGenerationService: workoutGenerationService ?? RulesWorkoutGenerationService(
        exerciseRepository: repos.exercise
      ),
      aiWorkoutService: aiWorkoutService ?? MockAIWorkoutService(),
      appleLanguageModeling: appleLanguageModeling ?? MockAppleLanguageModeling(),
      foodSearchService: foodSearchService ?? MockFoodSearchService(),
      bodyPhotoAnalyzer: analyzer,
      physiqueAssessmentService: physiqueAssessmentService ?? HybridPhysiqueAssessmentService(
        remote: UnavailablePhysiqueAssessmentService(),
        offline: OfflinePhysiqueAssessmentService(),
        analyzer: analyzer
      ),
      physiqueIllustrationService: physiqueIllustrationService ?? MockPhysiqueIllustrationService(),
      physiqueIllustrationStore: physiqueIllustrationStore,
      healthKitReadinessService: MockHealthKitReadinessService(),
      healthKitWorkoutExportService: MockHealthKitWorkoutExportService(),
      stravaIntegrationService: NoOpStravaIntegrationService(),
      authService: authService ?? NoOpAuthService(),
      cloudSyncService: cloudSyncService ?? NoOpCloudSyncService(),
      feedbackService: ForgeFeedbackService(),
      subscriptionService: ForgeSubscriptionService(grantProForTesting: true),
      workoutReminderScheduler: workoutReminderScheduler ?? NoOpWorkoutReminderScheduler(),
      physiqueReassessReminderScheduler: physiqueReassessReminderScheduler
        ?? NoOpPhysiqueReassessReminderScheduler()
    )
  }

  func seedOnboardedProfile(_ profile: UserProfile = UserProfile.empty()) async throws {
    try await userProfileRepository.saveProfile(profile)
    try await userProfileRepository.setOnboardingComplete(true)
    userProfile = profile
    hasCompletedOnboarding = true
    recoveryStates = RecoveryCalculator.defaultStates()
    try await recoveryRepository.saveRecoveryStates(recoveryStates)
  }
}

struct MockHealthKitReadinessService: HealthKitReadinessService {
  var isAvailable: Bool { false }
  var bodyMass: HealthBodyMassSample?
  func requestAuthorizationIfNeeded() async {}
  func fetchReadinessSnapshot() async -> HealthReadinessSnapshot { .empty }
  func fetchLatestBodyMass() async -> HealthBodyMassSample? { bodyMass }
}

final class MockHealthKitWorkoutExportService: HealthKitWorkoutExportService, @unchecked Sendable {
  var isAvailable: Bool { false }
  private(set) var exportedSessionIds: [UUID] = []

  func requestAuthorizationIfNeeded() async {}

  func exportCompletedWorkout(_ session: WorkoutSession, bodyWeightKg: Double) async {
    exportedSessionIds.append(session.id)
  }
}
