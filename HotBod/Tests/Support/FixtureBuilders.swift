import Foundation
@testable import HotBod

extension FixtureBuilders {
  static let legacyDeloadStatsJSON = """
  {
    "exerciseId": "squat",
    "preferredRepRangeMin": 5,
    "preferredRepRangeMax": 8,
    "recentSets": [],
    "isInDeloadWeek": true
  }
  """
}

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

  static func makeGeneratedWorkout(exerciseId: String = "bench_press") -> GeneratedWorkout {
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
      createdAt: Date()
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

@MainActor
extension AppEnvironment {
  static func makeForTests(
    repos: TestRepositories = .empty(),
    workoutGenerationService: (any WorkoutGenerationService)? = nil,
    aiWorkoutService: (any AIWorkoutService)? = nil,
    foodSearchService: (any FoodSearchService)? = nil,
    authService: (any AuthService)? = nil
  ) -> AppEnvironment {
    AppEnvironment(
      workoutRepository: repos.workout,
      exerciseRepository: repos.exercise,
      nutritionRepository: repos.nutrition,
      bodyProgressRepository: repos.bodyProgress,
      userProfileRepository: repos.userProfile,
      recoveryRepository: repos.recovery,
      exerciseStatsRepository: repos.exerciseStats,
      programStateRepository: repos.programState,
      coachRepository: repos.coach,
      workoutGenerationService: workoutGenerationService ?? RulesWorkoutGenerationService(
        exerciseRepository: repos.exercise
      ),
      aiWorkoutService: aiWorkoutService ?? MockAIWorkoutService(),
      foodSearchService: foodSearchService ?? MockFoodSearchService(),
      bodyPhotoAnalyzer: MockBodyPhotoAnalyzer(),
      healthKitReadinessService: MockHealthKitReadinessService(),
      healthKitWorkoutExportService: MockHealthKitWorkoutExportService(),
      stravaIntegrationService: NoOpStravaIntegrationService(),
      authService: authService ?? NoOpAuthService(),
      cloudSyncService: NoOpCloudSyncService(),
      feedbackService: ForgeFeedbackService(),
      subscriptionService: ForgeSubscriptionService(grantProForTesting: true)
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
  func requestAuthorizationIfNeeded() async {}
  func fetchReadinessSnapshot() async -> HealthReadinessSnapshot { .empty }
}

final class MockHealthKitWorkoutExportService: HealthKitWorkoutExportService, @unchecked Sendable {
  var isAvailable: Bool { false }
  private(set) var exportedSessionIds: [UUID] = []

  func requestAuthorizationIfNeeded() async {}

  func exportCompletedWorkout(_ session: WorkoutSession, bodyWeightKg: Double) async {
    exportedSessionIds.append(session.id)
  }
}
