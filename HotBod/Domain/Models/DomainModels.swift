import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String?
    var age: Int?
    var heightCm: Double?
    var weightKg: Double?
    var goal: TrainingGoal
    var experienceLevel: ExperienceLevel
    var trainingLocation: TrainingLocation
    var availableEquipment: [Equipment]
    var trainingDaysPerWeek: Int
    var preferredSessionLengthMinutes: Int
    var preferredSplit: TrainingSplit
    var preferredTrainingDays: [Weekday]
    var timeOfDayPreference: TimeOfDayPreference
    var limitations: [BodyLimitation]
    var limitationNotes: String?
    var preferredMuscleGroups: [MuscleGroup]?
    var avoidedMuscleGroups: [MuscleGroup]?
    var proteinGoalGrams: Double
    var photoTrackingEnabled: Bool
    var includeWarmupSets: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, age, goal, limitations, limitationNotes
        case heightCm, weightKg, experienceLevel, trainingLocation, availableEquipment
        case trainingDaysPerWeek, preferredSessionLengthMinutes, preferredSplit
        case preferredTrainingDays, timeOfDayPreference, preferredMuscleGroups, avoidedMuscleGroups
        case proteinGoalGrams, photoTrackingEnabled, includeWarmupSets, createdAt, updatedAt
    }

    init(
        id: UUID,
        name: String? = nil,
        age: Int? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        goal: TrainingGoal,
        experienceLevel: ExperienceLevel,
        trainingLocation: TrainingLocation,
        availableEquipment: [Equipment],
        trainingDaysPerWeek: Int,
        preferredSessionLengthMinutes: Int,
        preferredSplit: TrainingSplit,
        preferredTrainingDays: [Weekday],
        timeOfDayPreference: TimeOfDayPreference,
        limitations: [BodyLimitation],
        limitationNotes: String? = nil,
        preferredMuscleGroups: [MuscleGroup]? = nil,
        avoidedMuscleGroups: [MuscleGroup]? = nil,
        proteinGoalGrams: Double,
        photoTrackingEnabled: Bool,
        includeWarmupSets: Bool = true,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.goal = goal
        self.experienceLevel = experienceLevel
        self.trainingLocation = trainingLocation
        self.availableEquipment = availableEquipment
        self.trainingDaysPerWeek = trainingDaysPerWeek
        self.preferredSessionLengthMinutes = preferredSessionLengthMinutes
        self.preferredSplit = preferredSplit
        self.preferredTrainingDays = preferredTrainingDays
        self.timeOfDayPreference = timeOfDayPreference
        self.limitations = limitations
        self.limitationNotes = limitationNotes
        self.preferredMuscleGroups = preferredMuscleGroups
        self.avoidedMuscleGroups = avoidedMuscleGroups
        self.proteinGoalGrams = proteinGoalGrams
        self.photoTrackingEnabled = photoTrackingEnabled
        self.includeWarmupSets = includeWarmupSets
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        age = try container.decodeIfPresent(Int.self, forKey: .age)
        heightCm = try container.decodeIfPresent(Double.self, forKey: .heightCm)
        weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg)
        goal = try container.decode(TrainingGoal.self, forKey: .goal)
        experienceLevel = try container.decode(ExperienceLevel.self, forKey: .experienceLevel)
        trainingLocation = try container.decode(TrainingLocation.self, forKey: .trainingLocation)
        availableEquipment = try container.decode([Equipment].self, forKey: .availableEquipment)
        trainingDaysPerWeek = try container.decode(Int.self, forKey: .trainingDaysPerWeek)
        preferredSessionLengthMinutes = try container.decode(Int.self, forKey: .preferredSessionLengthMinutes)
        preferredSplit = try container.decode(TrainingSplit.self, forKey: .preferredSplit)
        preferredTrainingDays = try container.decode([Weekday].self, forKey: .preferredTrainingDays)
        timeOfDayPreference = try container.decode(TimeOfDayPreference.self, forKey: .timeOfDayPreference)
        limitations = try container.decode([BodyLimitation].self, forKey: .limitations)
        limitationNotes = try container.decodeIfPresent(String.self, forKey: .limitationNotes)
        preferredMuscleGroups = try container.decodeIfPresent([MuscleGroup].self, forKey: .preferredMuscleGroups)
        avoidedMuscleGroups = try container.decodeIfPresent([MuscleGroup].self, forKey: .avoidedMuscleGroups)
        proteinGoalGrams = try container.decode(Double.self, forKey: .proteinGoalGrams)
        photoTrackingEnabled = try container.decode(Bool.self, forKey: .photoTrackingEnabled)
        includeWarmupSets = try container.decodeIfPresent(Bool.self, forKey: .includeWarmupSets) ?? true
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    static func empty() -> UserProfile {
        UserProfile(
            id: UUID(),
            goal: .buildMuscle,
            experienceLevel: .intermediate,
            trainingLocation: .commercialGym,
            availableEquipment: Equipment.allCases,
            trainingDaysPerWeek: 4,
            preferredSessionLengthMinutes: 45,
            preferredSplit: .upperLower,
            preferredTrainingDays: [.monday, .tuesday, .thursday, .friday],
            timeOfDayPreference: .flexible,
            limitations: [],
            preferredMuscleGroups: [],
            avoidedMuscleGroups: [],
            proteinGoalGrams: 145,
            photoTrackingEnabled: false,
            includeWarmupSets: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

struct Exercise: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var slug: String
    var primaryMuscles: [MuscleGroup]
    var secondaryMuscles: [MuscleGroup]
    var equipment: [Equipment]
    var movementPattern: MovementPattern
    var difficulty: ExerciseDifficulty
    var forceType: ForceType?
    var mechanics: MechanicsType?
    var instructions: [String]
    var formCues: [String]
    var commonMistakes: [String]
    var contraindications: [String]
    var substitutions: [String]
    var progressions: [String]
    var regressions: [String]
    /// Alternate names shown in exercise detail (e.g. "BB Bench Press").
    var aliases: [String] = []
    /// Fitbod-style swap family — exercises in the same group target the same slot.
    var substitutionGroupId: String? = nil
    var demoVideos: [ExerciseDemoVideo]
    var imageUrl: URL?
    var tags: [String]
    var isFavorite: Bool = false
    var isAvoided: Bool = false
}

struct ExerciseDemoVideo: Codable, Hashable, Identifiable {
    let id: String
    let angle: DemoAngle
    let url: URL
    let thumbnailUrl: URL?
    let durationSeconds: Int?
    let isLoopable: Bool
    let license: MediaLicense
}

struct PlannedSet: Identifiable, Codable, Hashable {
    let id: UUID
    var targetRepsMin: Int
    var targetRepsMax: Int
    var targetWeightKg: Double?
    var rpeTarget: Double?
    var isWarmup: Bool

    init(
        id: UUID = UUID(),
        targetRepsMin: Int,
        targetRepsMax: Int,
        targetWeightKg: Double? = nil,
        rpeTarget: Double? = nil,
        isWarmup: Bool = false
    ) {
        self.id = id
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
        self.targetWeightKg = targetWeightKg
        self.rpeTarget = rpeTarget
        self.isWarmup = isWarmup
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        targetRepsMin = try container.decode(Int.self, forKey: .targetRepsMin)
        targetRepsMax = try container.decode(Int.self, forKey: .targetRepsMax)
        targetWeightKg = try container.decodeIfPresent(Double.self, forKey: .targetWeightKg)
        rpeTarget = try container.decodeIfPresent(Double.self, forKey: .rpeTarget)
        isWarmup = try container.decodeIfPresent(Bool.self, forKey: .isWarmup) ?? false
    }
}

struct CompletedSet: Identifiable, Codable, Hashable {
    let id: UUID
    var setIndex: Int
    var weightKg: Double?
    var reps: Int
    var rpe: Double?
    var completedAt: Date
    var isWarmup: Bool
    var isFailure: Bool

    init(
        id: UUID = UUID(),
        setIndex: Int,
        weightKg: Double? = nil,
        reps: Int = 0,
        rpe: Double? = nil,
        completedAt: Date = Date(),
        isWarmup: Bool = false,
        isFailure: Bool = false
    ) {
        self.id = id
        self.setIndex = setIndex
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.completedAt = completedAt
        self.isWarmup = isWarmup
        self.isFailure = isFailure
    }
}

struct PlannedExercise: Identifiable, Codable, Hashable {
    let id: UUID
    let exerciseId: String
    var orderIndex: Int
    var targetSets: [PlannedSet]
    var restSeconds: Int
    var intensity: IntensityTarget
    var reason: String

    init(
        id: UUID = UUID(),
        exerciseId: String,
        orderIndex: Int,
        targetSets: [PlannedSet],
        restSeconds: Int = 90,
        intensity: IntensityTarget = .moderate,
        reason: String = ""
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.orderIndex = orderIndex
        self.targetSets = targetSets
        self.restSeconds = restSeconds
        self.intensity = intensity
        self.reason = reason
    }
}

enum IntensityTarget: String, Codable {
    case light, moderate, heavy
}

enum SessionMode: String, Codable, Hashable {
    case standard, recovery
}

struct GeneratedWorkout: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var estimatedDurationMinutes: Int
    var focus: [MuscleGroup]
    var exercises: [PlannedExercise]
    var rationale: String
    var safetyNotes: [String]
    var generatedBy: WorkoutGenerationSource
    var createdAt: Date
    var sessionMode: SessionMode = .standard
}

struct WorkoutExercise: Identifiable, Codable, Hashable {
    let id: UUID
    let exerciseId: String
    var orderIndex: Int
    var plannedSets: [PlannedSet]
    var completedSets: [CompletedSet]
    var restSeconds: Int
    var notes: String?
    var wasSkipped: Bool
    var skipReason: String?

    init(
        id: UUID = UUID(),
        exerciseId: String,
        orderIndex: Int,
        plannedSets: [PlannedSet],
        completedSets: [CompletedSet] = [],
        restSeconds: Int = 90,
        notes: String? = nil,
        wasSkipped: Bool = false,
        skipReason: String? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.orderIndex = orderIndex
        self.plannedSets = plannedSets
        self.completedSets = completedSets
        self.restSeconds = restSeconds
        self.notes = notes
        self.wasSkipped = wasSkipped
        self.skipReason = skipReason
    }
}

struct WorkoutSession: Identifiable, Codable, Hashable {
    let id: UUID
    let userId: UUID
    var title: String
    var startedAt: Date?
    var completedAt: Date?
    var estimatedDurationMinutes: Int
    var exercises: [WorkoutExercise]
    var notes: String?
    var perceivedDifficulty: Int?
    var status: WorkoutStatus

    init(
        id: UUID = UUID(),
        userId: UUID,
        title: String,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        estimatedDurationMinutes: Int,
        exercises: [WorkoutExercise],
        notes: String? = nil,
        perceivedDifficulty: Int? = nil,
        status: WorkoutStatus = .planned
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.exercises = exercises
        self.notes = notes
        self.perceivedDifficulty = perceivedDifficulty
        self.status = status
    }
}

struct WorkoutSessionSummary: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var completedAt: Date
    var totalVolumeKg: Double
    var totalSets: Int
    var durationMinutes: Int
    var muscleGroups: [MuscleGroup]
}

struct MuscleRecoveryState: Codable, Hashable, Identifiable {
    var muscleGroup: MuscleGroup
    var recoveryPercentage: Double
    var lastTrainedAt: Date?
    var accumulatedFatigue: Double

    var id: String { muscleGroup.rawValue }
}

struct UserExerciseStats: Identifiable, Codable, Hashable {
    let exerciseId: String
    var lastWeightKg: Double?
    var lastReps: Int?
    var suggestedNextWeightKg: Double?
    var estimatedOneRepMax: Double?
    var bestVolumeSet: Double?
    var recentSets: [CompletedSet]
    var preferredRepRangeMin: Int
    var preferredRepRangeMax: Int
    
    // Volume tracking (last 12 weeks of weekly volume in reps)
    var weeklyVolume: [Int] = []
    var weeklyMaxSets: Int = 0
    var volumeTrend: TrendDirection = .stable
    
    // Deload tracking
    var isInDeloadWeek: Bool = false
    var lastDeloadDate: Date?
    var consecutiveHighVolumeWeeks: Int = 0

    var id: String { exerciseId }

    var preferredRepRange: ClosedRange<Int> {
        preferredRepRangeMin...preferredRepRangeMax
    }

    var planningWeightKg: Double? {
        suggestedNextWeightKg ?? lastWeightKg
    }
}

struct ProteinEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var date: Date
    var mealType: MealType
    var foodName: String
    var servingDescription: String?
    var proteinGrams: Double
    var calories: Double?
    var carbsGrams: Double?
    var fatGrams: Double?
    var source: NutritionDataSource

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        mealType: MealType = .snack,
        foodName: String,
        servingDescription: String? = nil,
        proteinGrams: Double,
        calories: Double? = nil,
        carbsGrams: Double? = nil,
        fatGrams: Double? = nil,
        source: NutritionDataSource = .manual
    ) {
        self.id = id
        self.date = date
        self.mealType = mealType
        self.foodName = foodName
        self.servingDescription = servingDescription
        self.proteinGrams = proteinGrams
        self.calories = calories
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.source = source
    }
}

struct BodyPhotoAnalysis: Codable, Hashable {
    var poseConfidence: Double
    var lightingScore: Double
    var framingScore: Double
    var shoulderWidthEstimate: Double?
    var waistWidthEstimate: Double?
    var hipWidthEstimate: Double?
    var shoulderWaistRatio: Double?
    var postureNotes: [String]
    var comparisonSummary: String?
    var limitations: [String]
}

struct BodyProgressPhoto: Identifiable, Codable, Hashable {
    let id: UUID
    let userId: UUID
    var date: Date
    var poseType: BodyPhotoPoseType
    var localImagePath: String
    var remoteImageUrl: URL?
    var weightKg: Double?
    var notes: String?
    var analysis: BodyPhotoAnalysis?
}

struct CoachMessage: Identifiable, Codable, Hashable {
    let id: UUID
    var role: CoachMessageRole
    var content: String
    var createdAt: Date
    var intent: CoachIntent?
}

enum CoachMessageRole: String, Codable {
    case user, assistant, system
}

struct WorkoutPreferences: Codable, Hashable {
    var avoidExerciseIds: [String] = []
    var favoriteExerciseIds: [String] = []
    var preferVariation: Bool = false
}

struct ReadinessInput: Codable, Hashable {
    var sleepScore: Double?
    var soreness: SorenessLevel
    var manualReadiness: Double?
}

struct HealthReadinessSnapshot: Codable, Hashable {
    var restingHeartRateBPM: Double?
    var sleepHoursLastNight: Double?
    var recoveryHint: String?
    var sleepScore: Double?

    static let empty = HealthReadinessSnapshot()
}

struct WorkoutGenerationInput: Codable {
    let userProfile: UserProfile
    let goal: TrainingGoal
    let experienceLevel: ExperienceLevel
    let availableEquipment: [Equipment]
    let targetDurationMinutes: Int
    let preferredMuscleGroups: [MuscleGroup]
    let avoidedMuscleGroups: [MuscleGroup]
    let injuries: [BodyLimitation]
    let recentWorkouts: [WorkoutSessionSummary]
    let muscleRecovery: [MuscleGroup: Double]
    let exerciseStats: [UserExerciseStats]
    let userPreferences: WorkoutPreferences
    let readiness: ReadinessInput?
    let splitDayFocus: SplitDayFocus?
}

struct WorkoutValidationResult: Codable {
    let isValid: Bool
    let errors: [String]
    let warnings: [String]
    let suggestions: [String]

    init(isValid: Bool, errors: [String], warnings: [String], suggestions: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
        self.suggestions = suggestions
    }
}

struct ProteinSummary: Codable, Hashable {
    var todayGrams: Double
    var goalGrams: Double
    var streakDays: Int
}

struct BodyProgressSummary: Codable, Hashable {
    var photoCount: Int
    var latestPhotoDate: Date?
    var averageLightingScore: Double?
}

struct UserProfileSummary: Codable, Hashable {
    var goal: TrainingGoal
    var experienceLevel: ExperienceLevel
    var proteinGoalGrams: Double
}

struct CoachContext: Codable {
    let userProfile: UserProfileSummary
    let currentWorkout: GeneratedWorkout?
    let recentWorkouts: [WorkoutSessionSummary]
    let exerciseStats: [UserExerciseStats]
    let proteinSummary: ProteinSummary
    let bodyProgressSummary: BodyProgressSummary
    let recovery: [MuscleGroup: Double]
    let limitations: [BodyLimitation]
    let allowedExerciseIds: [String]
    let availableEquipment: [Equipment]
    let targetDurationMinutes: Int
}

struct FoodSearchResult: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var brand: String?
    var proteinPer100g: Double?
}

struct FoodNutritionDetails: Codable, Hashable {
    let id: String
    var name: String
    var proteinGrams: Double
    var calories: Double?
    var servingSize: String?
}
