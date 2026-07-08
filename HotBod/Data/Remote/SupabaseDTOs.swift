import Foundation

// MARK: - DTOs

struct ProfileRow: Codable {
    let id: UUID
    var name: String?
    var age: Int?
    var heightCm: Double?
    var weightKg: Double?
    var goal: String
    var experienceLevel: String
    var trainingLocation: String?
    var trainingDaysPerWeek: Int?
    var preferredSessionLengthMinutes: Int?
    var preferredSplit: String?
    var proteinGoalGrams: Double?
    var photoTrackingEnabled: Bool?
    var onboardingComplete: Bool?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, age, goal
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case experienceLevel = "experience_level"
        case trainingLocation = "training_location"
        case trainingDaysPerWeek = "training_days_per_week"
        case preferredSessionLengthMinutes = "preferred_session_length_minutes"
        case preferredSplit = "preferred_split"
        case proteinGoalGrams = "protein_goal_grams"
        case photoTrackingEnabled = "photo_tracking_enabled"
        case onboardingComplete = "onboarding_complete"
        case updatedAt = "updated_at"
    }

    init(from profile: UserProfile, userId: UUID? = nil) {
        id = userId ?? profile.id
        name = profile.name
        age = profile.age
        heightCm = profile.heightCm
        weightKg = profile.weightKg
        goal = profile.goal.rawValue
        experienceLevel = profile.experienceLevel.rawValue
        trainingLocation = profile.trainingLocation.rawValue
        trainingDaysPerWeek = profile.trainingDaysPerWeek
        preferredSessionLengthMinutes = profile.preferredSessionLengthMinutes
        preferredSplit = profile.preferredSplit.rawValue
        proteinGoalGrams = profile.proteinGoalGrams
        photoTrackingEnabled = profile.photoTrackingEnabled
        onboardingComplete = true
        updatedAt = profile.updatedAt
    }

    func toUserProfile(fallback: UserProfile?) -> UserProfile {
        UserProfile(
            id: id,
            name: name ?? fallback?.name,
            age: age ?? fallback?.age,
            heightCm: heightCm ?? fallback?.heightCm,
            weightKg: weightKg ?? fallback?.weightKg,
            goal: TrainingGoal(rawValue: goal) ?? fallback?.goal ?? .buildMuscle,
            experienceLevel: ExperienceLevel(rawValue: experienceLevel) ?? fallback?.experienceLevel ?? .intermediate,
            trainingLocation: TrainingLocation(rawValue: trainingLocation ?? "") ?? fallback?.trainingLocation ?? .commercialGym,
            availableEquipment: fallback?.availableEquipment ?? Equipment.allCases,
            trainingDaysPerWeek: trainingDaysPerWeek ?? fallback?.trainingDaysPerWeek ?? 4,
            preferredSessionLengthMinutes: preferredSessionLengthMinutes ?? fallback?.preferredSessionLengthMinutes ?? 45,
            preferredSplit: TrainingSplit(rawValue: preferredSplit ?? "") ?? fallback?.preferredSplit ?? .upperLower,
            preferredTrainingDays: fallback?.preferredTrainingDays ?? [.monday, .tuesday, .thursday, .friday],
            timeOfDayPreference: fallback?.timeOfDayPreference ?? .flexible,
            limitations: fallback?.limitations ?? [],
            limitationNotes: fallback?.limitationNotes,
            proteinGoalGrams: proteinGoalGrams ?? fallback?.proteinGoalGrams ?? 145,
            photoTrackingEnabled: photoTrackingEnabled ?? fallback?.photoTrackingEnabled ?? false,
            includeWarmupSets: fallback?.includeWarmupSets ?? true,
            createdAt: fallback?.createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }
}

struct UserPrefsPull: Decodable {
    var todayWorkoutJson: GeneratedWorkout?
    var photoCloudBackupEnabled: Bool?
    var programStateJson: TrainingProgramState?

    enum CodingKeys: String, CodingKey {
        case todayWorkoutJson = "today_workout_json"
        case photoCloudBackupEnabled = "photo_cloud_backup_enabled"
        case programStateJson = "program_state_json"
    }
}

struct UserPreferencesRow: Codable {
    let userId: UUID
    var photoCloudBackupEnabled: Bool
    var aiInsightOptIn: Bool
    var todayWorkoutJson: Data?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case photoCloudBackupEnabled = "photo_cloud_backup_enabled"
        case aiInsightOptIn = "ai_insight_opt_in"
        case todayWorkoutJson = "today_workout_json"
    }
}

struct ProteinEntryRow: Codable {
    let id: UUID
    let userId: UUID
    var entryDate: String
    var mealType: String?
    var foodName: String
    var servingDescription: String?
    var proteinGrams: Double
    var calories: Double?
    var carbsGrams: Double?
    var fatGrams: Double?
    var source: String?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case entryDate = "entry_date"
        case mealType = "meal_type"
        case foodName = "food_name"
        case servingDescription = "serving_description"
        case proteinGrams = "protein_grams"
        case calories
        case carbsGrams = "carbs_grams"
        case fatGrams = "fat_grams"
        case source
        case updatedAt = "updated_at"
    }

    init(entry: ProteinEntry, userId: UUID) {
        id = entry.id
        self.userId = userId
        entryDate = Self.dateFormatter.string(from: entry.date)
        mealType = entry.mealType.rawValue
        foodName = entry.foodName
        servingDescription = entry.servingDescription
        proteinGrams = entry.proteinGrams
        calories = entry.calories
        carbsGrams = entry.carbsGrams
        fatGrams = entry.fatGrams
        source = entry.source.rawValue
        updatedAt = Date()
    }

    func toEntry() -> ProteinEntry? {
        guard let meal = MealType(rawValue: mealType ?? "snack"),
              let date = Self.dateFormatter.date(from: entryDate) else { return nil }
        return ProteinEntry(
            id: id,
            date: date,
            mealType: meal,
            foodName: foodName,
            servingDescription: servingDescription,
            proteinGrams: proteinGrams,
            calories: calories,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            source: NutritionDataSource(rawValue: source ?? "manual") ?? .manual
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

struct WorkoutSessionRow: Codable {
    let id: UUID
    let userId: UUID
    var title: String
    var startedAt: Date?
    var completedAt: Date?
    var estimatedDurationMinutes: Int?
    var perceivedDifficulty: Int?
    var notes: String?
    var status: String
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case estimatedDurationMinutes = "estimated_duration_minutes"
        case perceivedDifficulty = "perceived_difficulty"
        case notes, status
        case updatedAt = "updated_at"
    }

    init(session: WorkoutSession, userId: UUID? = nil) {
        id = session.id
        self.userId = userId ?? session.userId
        title = session.title
        startedAt = session.startedAt
        completedAt = session.completedAt
        estimatedDurationMinutes = session.estimatedDurationMinutes
        perceivedDifficulty = session.perceivedDifficulty
        notes = session.notes
        status = session.status.rawValue
        updatedAt = Date()
    }
}

struct WorkoutExerciseRow: Codable {
    let id: UUID
    let workoutSessionId: UUID
    let exerciseId: String
    var orderIndex: Int
    var restSeconds: Int
    var notes: String?
    var wasSkipped: Bool
    var skipReason: String?
    var plannedSets: [PlannedSet]

    enum CodingKeys: String, CodingKey {
        case id
        case workoutSessionId = "workout_session_id"
        case exerciseId = "exercise_id"
        case orderIndex = "order_index"
        case restSeconds = "rest_seconds"
        case notes
        case wasSkipped = "was_skipped"
        case skipReason = "skip_reason"
        case plannedSets = "planned_sets"
    }

    init(exercise: WorkoutExercise, sessionId: UUID) {
        id = exercise.id
        workoutSessionId = sessionId
        exerciseId = exercise.exerciseId
        orderIndex = exercise.orderIndex
        restSeconds = exercise.restSeconds
        notes = exercise.notes
        wasSkipped = exercise.wasSkipped
        skipReason = exercise.skipReason
        plannedSets = exercise.plannedSets
    }
}

struct CompletedSetRow: Codable {
    let id: UUID
    let workoutExerciseId: UUID
    var setIndex: Int
    var weightKg: Double?
    var reps: Int
    var rpe: Double?
    var isWarmup: Bool
    var isFailure: Bool
    var completedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case workoutExerciseId = "workout_exercise_id"
        case setIndex = "set_index"
        case weightKg = "weight_kg"
        case reps, rpe
        case isWarmup = "is_warmup"
        case isFailure = "is_failure"
        case completedAt = "completed_at"
    }

    init(set: CompletedSet, workoutExerciseId: UUID) {
        id = set.id
        self.workoutExerciseId = workoutExerciseId
        setIndex = set.setIndex
        weightKg = set.weightKg
        reps = set.reps
        rpe = set.rpe
        isWarmup = set.isWarmup
        isFailure = set.isFailure
        completedAt = set.completedAt
    }
}

struct BodyPhotoRow: Codable {
    let id: UUID
    let userId: UUID
    var poseType: String
    var storagePath: String?
    var weightKg: Double?
    var notes: String?
    var analysisJson: BodyPhotoAnalysis?
    var capturedAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case poseType = "pose_type"
        case storagePath = "storage_path"
        case weightKg = "weight_kg"
        case notes
        case analysisJson = "analysis_json"
        case capturedAt = "captured_at"
        case updatedAt = "updated_at"
    }

    func toBodyProgressPhoto(localImagePath: String) -> BodyProgressPhoto {
        BodyProgressPhoto(
            id: id,
            userId: userId,
            date: capturedAt ?? Date(),
            poseType: BodyPhotoPoseType(rawValue: poseType) ?? .frontRelaxed,
            localImagePath: localImagePath,
            remoteImageUrl: nil,
            weightKg: weightKg,
            notes: notes,
            analysis: analysisJson
        )
    }
}

struct CoachMessageRow: Codable {
    let id: UUID
    let userId: UUID
    var role: String
    var content: String
    var intent: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case role, content, intent
        case createdAt = "created_at"
    }

    var toMessage: CoachMessage {
        CoachMessage(
            id: id,
            role: CoachMessageRole(rawValue: role) ?? .assistant,
            content: content,
            createdAt: createdAt ?? Date(),
            intent: intent.flatMap { CoachIntent(rawValue: $0) }
        )
    }
}

struct MuscleRecoveryRow: Codable {
    let userId: UUID
    let muscleGroup: String
    var recoveryPercentage: Double
    var lastTrainedAt: Date?
    var accumulatedFatigue: Double
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case muscleGroup = "muscle_group"
        case recoveryPercentage = "recovery_percentage"
        case lastTrainedAt = "last_trained_at"
        case accumulatedFatigue = "accumulated_fatigue"
        case updatedAt = "updated_at"
    }

    init(state: MuscleRecoveryState, userId: UUID) {
        self.userId = userId
        muscleGroup = state.muscleGroup.rawValue
        recoveryPercentage = state.recoveryPercentage
        lastTrainedAt = state.lastTrainedAt
        accumulatedFatigue = state.accumulatedFatigue
        updatedAt = Date()
    }

    var toState: MuscleRecoveryState {
        MuscleRecoveryState(
            muscleGroup: MuscleGroup(rawValue: muscleGroup) ?? .chest,
            recoveryPercentage: recoveryPercentage,
            lastTrainedAt: lastTrainedAt,
            accumulatedFatigue: accumulatedFatigue
        )
    }
}

struct UserExerciseStatsRow: Codable {
    let userId: UUID
    let exerciseId: String
    var lastWeightKg: Double?
    var lastReps: Int?
    var suggestedNextWeightKg: Double?
    var estimatedOneRepMax: Double?
    var bestVolumeSet: Double?
    var recentSets: [CompletedSet]
    var preferredRepRangeMin: Int
    var preferredRepRangeMax: Int
    var weeklyVolume: [Int]
    var weeklyMaxSets: Int
    var volumeTrend: String
    var deloadStartedAt: Date?
    var returningFromBreak: Bool
    var goalAtLastUpdate: String?
    var consecutiveHighVolumeWeeks: Int
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case exerciseId = "exercise_id"
        case lastWeightKg = "last_weight_kg"
        case lastReps = "last_reps"
        case suggestedNextWeightKg = "suggested_next_weight_kg"
        case estimatedOneRepMax = "estimated_one_rep_max"
        case bestVolumeSet = "best_volume_set"
        case recentSets = "recent_sets"
        case preferredRepRangeMin = "preferred_rep_range_min"
        case preferredRepRangeMax = "preferred_rep_range_max"
        case weeklyVolume = "weekly_volume"
        case weeklyMaxSets = "weekly_max_sets"
        case volumeTrend = "volume_trend"
        case deloadStartedAt = "deload_started_at"
        case returningFromBreak = "returning_from_break"
        case goalAtLastUpdate = "goal_at_last_update"
        case consecutiveHighVolumeWeeks = "consecutive_high_volume_weeks"
        case updatedAt = "updated_at"
        case legacyIsInDeloadWeek = "is_in_deload_week"
        case legacyLastDeloadDate = "last_deload_date"
    }

    init(stat: UserExerciseStats, userId: UUID) {
        self.userId = userId
        exerciseId = stat.exerciseId
        lastWeightKg = stat.lastWeightKg
        lastReps = stat.lastReps
        suggestedNextWeightKg = stat.suggestedNextWeightKg
        estimatedOneRepMax = stat.estimatedOneRepMax
        bestVolumeSet = stat.bestVolumeSet
        recentSets = stat.recentSets
        preferredRepRangeMin = stat.preferredRepRangeMin
        preferredRepRangeMax = stat.preferredRepRangeMax
        weeklyVolume = stat.weeklyVolume
        weeklyMaxSets = stat.weeklyMaxSets
        volumeTrend = stat.volumeTrend.rawValue
        deloadStartedAt = stat.deloadStartedAt
        returningFromBreak = stat.returningFromBreak
        goalAtLastUpdate = stat.goalAtLastUpdate?.rawValue
        consecutiveHighVolumeWeeks = stat.consecutiveHighVolumeWeeks
        updatedAt = Date()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        exerciseId = try container.decode(String.self, forKey: .exerciseId)
        lastWeightKg = try container.decodeIfPresent(Double.self, forKey: .lastWeightKg)
        lastReps = try container.decodeIfPresent(Int.self, forKey: .lastReps)
        suggestedNextWeightKg = try container.decodeIfPresent(Double.self, forKey: .suggestedNextWeightKg)
        estimatedOneRepMax = try container.decodeIfPresent(Double.self, forKey: .estimatedOneRepMax)
        bestVolumeSet = try container.decodeIfPresent(Double.self, forKey: .bestVolumeSet)
        recentSets = try container.decodeIfPresent([CompletedSet].self, forKey: .recentSets) ?? []
        preferredRepRangeMin = try container.decode(Int.self, forKey: .preferredRepRangeMin)
        preferredRepRangeMax = try container.decode(Int.self, forKey: .preferredRepRangeMax)
        weeklyVolume = try container.decodeIfPresent([Int].self, forKey: .weeklyVolume) ?? []
        weeklyMaxSets = try container.decodeIfPresent(Int.self, forKey: .weeklyMaxSets) ?? 0
        volumeTrend = try container.decodeIfPresent(String.self, forKey: .volumeTrend) ?? TrendDirection.stable.rawValue
        deloadStartedAt = try container.decodeIfPresent(Date.self, forKey: .deloadStartedAt)
        if deloadStartedAt == nil,
           try container.decodeIfPresent(Bool.self, forKey: .legacyIsInDeloadWeek) == true {
            deloadStartedAt = try container.decodeIfPresent(Date.self, forKey: .legacyLastDeloadDate) ?? Date()
        }
        returningFromBreak = try container.decodeIfPresent(Bool.self, forKey: .returningFromBreak) ?? false
        goalAtLastUpdate = try container.decodeIfPresent(String.self, forKey: .goalAtLastUpdate)
        consecutiveHighVolumeWeeks = try container.decodeIfPresent(Int.self, forKey: .consecutiveHighVolumeWeeks) ?? 0
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(exerciseId, forKey: .exerciseId)
        try container.encodeIfPresent(lastWeightKg, forKey: .lastWeightKg)
        try container.encodeIfPresent(lastReps, forKey: .lastReps)
        try container.encodeIfPresent(suggestedNextWeightKg, forKey: .suggestedNextWeightKg)
        try container.encodeIfPresent(estimatedOneRepMax, forKey: .estimatedOneRepMax)
        try container.encodeIfPresent(bestVolumeSet, forKey: .bestVolumeSet)
        try container.encode(recentSets, forKey: .recentSets)
        try container.encode(preferredRepRangeMin, forKey: .preferredRepRangeMin)
        try container.encode(preferredRepRangeMax, forKey: .preferredRepRangeMax)
        try container.encode(weeklyVolume, forKey: .weeklyVolume)
        try container.encode(weeklyMaxSets, forKey: .weeklyMaxSets)
        try container.encode(volumeTrend, forKey: .volumeTrend)
        try container.encodeIfPresent(deloadStartedAt, forKey: .deloadStartedAt)
        try container.encode(returningFromBreak, forKey: .returningFromBreak)
        try container.encodeIfPresent(goalAtLastUpdate, forKey: .goalAtLastUpdate)
        try container.encode(consecutiveHighVolumeWeeks, forKey: .consecutiveHighVolumeWeeks)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }

    var toStats: UserExerciseStats {
        var stats = UserExerciseStats(
            exerciseId: exerciseId,
            lastWeightKg: lastWeightKg,
            lastReps: lastReps,
            suggestedNextWeightKg: suggestedNextWeightKg,
            estimatedOneRepMax: estimatedOneRepMax,
            bestVolumeSet: bestVolumeSet,
            recentSets: recentSets,
            preferredRepRangeMin: preferredRepRangeMin,
            preferredRepRangeMax: preferredRepRangeMax,
            goalAtLastUpdate: goalAtLastUpdate.flatMap(TrainingGoal.init(rawValue:)),
            deloadStartedAt: deloadStartedAt,
            returningFromBreak: returningFromBreak
        )
        stats.weeklyVolume = weeklyVolume
        stats.weeklyMaxSets = weeklyMaxSets
        stats.volumeTrend = TrendDirection(rawValue: volumeTrend) ?? .stable
        stats.consecutiveHighVolumeWeeks = consecutiveHighVolumeWeeks
        return stats
    }
}
