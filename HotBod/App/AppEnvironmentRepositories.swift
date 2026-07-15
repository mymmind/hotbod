import Foundation

/// Bundled persistence dependencies for `AppEnvironment` orchestration.
/// Features should call intent methods on `AppEnvironment`, not reach into repositories directly.
struct AppEnvironmentRepositories {
    let workout: any WorkoutRepository
    let exercise: any ExerciseRepository
    let nutrition: any NutritionRepository
    let bodyProgress: any BodyProgressRepository
    let userProfile: any UserProfileRepository
    let recovery: any RecoveryRepository
    let exerciseStats: any ExerciseStatsRepository
    let programState: any ProgramStateRepository
    let coach: any CoachRepository

    init(
        workout: any WorkoutRepository = LocalWorkoutRepository(),
        exercise: any ExerciseRepository = LocalExerciseRepository(),
        nutrition: any NutritionRepository = LocalNutritionRepository(),
        bodyProgress: any BodyProgressRepository = LocalBodyProgressRepository(),
        userProfile: any UserProfileRepository = LocalUserProfileRepository(),
        recovery: any RecoveryRepository = LocalRecoveryRepository(),
        exerciseStats: any ExerciseStatsRepository = LocalExerciseStatsRepository(),
        programState: any ProgramStateRepository = LocalProgramStateRepository(),
        coach: any CoachRepository = LocalCoachRepository()
    ) {
        self.workout = workout
        self.exercise = exercise
        self.nutrition = nutrition
        self.bodyProgress = bodyProgress
        self.userProfile = userProfile
        self.recovery = recovery
        self.exerciseStats = exerciseStats
        self.programState = programState
        self.coach = coach
    }

    var syncStores: SyncLocalStores {
        SyncLocalStores(
            userProfile: userProfile,
            workout: workout,
            exercise: exercise,
            nutrition: nutrition,
            bodyProgress: bodyProgress,
            recovery: recovery,
            exerciseStats: exerciseStats,
            coach: coach,
            programState: programState
        )
    }
}
