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
    var includeCooldown: Bool
    var preferredExerciseGrouping: ExerciseGroupingPreference
    var preferredExerciseVariability: ExerciseVariabilityLevel
    var cardioBlockPlacement: CardioBlockPlacement
    var includeConditioning: Bool
    var includeCoreFinisher: Bool
    var maxAvailableWeightKg: [Equipment: Double]
    var exportWorkoutsToHealthKit: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, age, goal, limitations, limitationNotes
        case heightCm, weightKg, experienceLevel, trainingLocation, availableEquipment
        case trainingDaysPerWeek, preferredSessionLengthMinutes, preferredSplit
        case preferredTrainingDays, timeOfDayPreference, preferredMuscleGroups, avoidedMuscleGroups
        case proteinGoalGrams, photoTrackingEnabled, includeWarmupSets, includeCooldown
        case preferredExerciseGrouping, preferredExerciseVariability, cardioBlockPlacement
        case includeConditioning, includeCoreFinisher
        case maxAvailableWeightKg
        case exportWorkoutsToHealthKit
        case createdAt, updatedAt
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
        includeCooldown: Bool = false,
        preferredExerciseGrouping: ExerciseGroupingPreference = .none,
        preferredExerciseVariability: ExerciseVariabilityLevel = .balanced,
        cardioBlockPlacement: CardioBlockPlacement = .none,
        includeConditioning: Bool = false,
        includeCoreFinisher: Bool = true,
        maxAvailableWeightKg: [Equipment: Double] = [:],
        exportWorkoutsToHealthKit: Bool = false,
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
        self.includeCooldown = includeCooldown
        self.preferredExerciseGrouping = preferredExerciseGrouping
        self.preferredExerciseVariability = preferredExerciseVariability
        self.cardioBlockPlacement = cardioBlockPlacement
        self.includeConditioning = includeConditioning
        self.includeCoreFinisher = includeCoreFinisher
        self.maxAvailableWeightKg = maxAvailableWeightKg
        self.exportWorkoutsToHealthKit = exportWorkoutsToHealthKit
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
        includeCooldown = try container.decodeIfPresent(Bool.self, forKey: .includeCooldown) ?? false
        preferredExerciseGrouping = try container.decodeIfPresent(
            ExerciseGroupingPreference.self,
            forKey: .preferredExerciseGrouping
        ) ?? .none
        preferredExerciseVariability = try container.decodeIfPresent(
            ExerciseVariabilityLevel.self,
            forKey: .preferredExerciseVariability
        ) ?? .balanced
        cardioBlockPlacement = try container.decodeIfPresent(
            CardioBlockPlacement.self,
            forKey: .cardioBlockPlacement
        ) ?? .none
        includeConditioning = try container.decodeIfPresent(Bool.self, forKey: .includeConditioning) ?? false
        includeCoreFinisher = try container.decodeIfPresent(Bool.self, forKey: .includeCoreFinisher) ?? true
        maxAvailableWeightKg = try container.decodeIfPresent([Equipment: Double].self, forKey: .maxAvailableWeightKg) ?? [:]
        exportWorkoutsToHealthKit = try container.decodeIfPresent(Bool.self, forKey: .exportWorkoutsToHealthKit) ?? false
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
            limitations: [.none],
            preferredMuscleGroups: [],
            avoidedMuscleGroups: [],
            proteinGoalGrams: 145,
            photoTrackingEnabled: false,
            includeWarmupSets: true,
            includeCooldown: false,
            preferredExerciseGrouping: .none,
            preferredExerciseVariability: .balanced,
            cardioBlockPlacement: .none,
            maxAvailableWeightKg: [:],
            exportWorkoutsToHealthKit: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func realigned(to newId: UUID) -> UserProfile {
        UserProfile(
            id: newId,
            name: name,
            age: age,
            heightCm: heightCm,
            weightKg: weightKg,
            goal: goal,
            experienceLevel: experienceLevel,
            trainingLocation: trainingLocation,
            availableEquipment: availableEquipment,
            trainingDaysPerWeek: trainingDaysPerWeek,
            preferredSessionLengthMinutes: preferredSessionLengthMinutes,
            preferredSplit: preferredSplit,
            preferredTrainingDays: preferredTrainingDays,
            timeOfDayPreference: timeOfDayPreference,
            limitations: limitations,
            limitationNotes: limitationNotes,
            preferredMuscleGroups: preferredMuscleGroups,
            avoidedMuscleGroups: avoidedMuscleGroups,
            proteinGoalGrams: proteinGoalGrams,
            photoTrackingEnabled: photoTrackingEnabled,
            includeWarmupSets: includeWarmupSets,
            includeCooldown: includeCooldown,
            preferredExerciseGrouping: preferredExerciseGrouping,
            preferredExerciseVariability: preferredExerciseVariability,
            cardioBlockPlacement: cardioBlockPlacement,
            includeConditioning: includeConditioning,
            includeCoreFinisher: includeCoreFinisher,
            maxAvailableWeightKg: maxAvailableWeightKg,
            exportWorkoutsToHealthKit: exportWorkoutsToHealthKit,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}

enum ExercisePreference: String, Codable, CaseIterable, Hashable {
    case neutral
    case favorite
    case less
    case excluded

    var displayName: String {
        switch self {
        case .neutral: "Default"
        case .favorite: "Recommend More"
        case .less: "Recommend Less"
        case .excluded: "Never Show"
        }
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
    /// Source-of-truth for whether the UI/workout logs should treat this exercise as externally loadable.
    /// Falls back to legacy heuristics/overrides when nil (e.g. old seed data).
    var loadTrackingMode: LoadTrackingMode? = nil
    var weightDisplaySemantics: WeightDisplaySemantics? = nil
    var prescriptionType: PrescriptionType? = nil
    var defaultDurationSeconds: Int? = nil
    var defaultDistanceMeters: Double? = nil
    /// Alternate names shown in exercise detail (e.g. "BB Bench Press").
    var aliases: [String] = []
    /// Fitbod-style swap family — exercises in the same group target the same slot.
    var substitutionGroupId: String? = nil
    var demoVideos: [ExerciseDemoVideo]
    var imageUrl: URL?
    var tags: [String]
    var preference: ExercisePreference = .neutral
    var isCustom: Bool = false

    var isFavorite: Bool { preference == .favorite }
    var isAvoided: Bool { preference == .excluded }
    var isLessPreferred: Bool { preference == .less }

    /// Resolves `loadTrackingMode` for legacy data.
    /// - Overrides: explicit mapping for known exercises.
    /// - Fallback: only used when both the field and override are missing.
    var resolvedLoadTrackingMode: LoadTrackingMode {
        if let loadTrackingMode {
            return loadTrackingMode
        }
        if let override = ExerciseLoadTrackingOverrides.map[id] {
            return override
        }
        // Legacy fallback: treat non-bodyweight-tagged movements as externally loadable.
        // This exists only to keep older seed content working.
        let hasNonBodyweightEquipment = equipment.contains(where: { $0 != .bodyweight })
        return hasNonBodyweightEquipment ? .supported : .none
    }

    var usesBodyweightLoading: Bool {
        !equipment.isEmpty && equipment.allSatisfy { $0 == .bodyweight }
    }

    var resolvedWeightDisplaySemantics: WeightDisplaySemantics {
        ExerciseMetadataResolver.resolvedWeightDisplaySemantics(for: self)
    }

    var resolvedPrescriptionType: PrescriptionType {
        ExerciseMetadataResolver.resolvedPrescriptionType(for: self)
    }
}

/// Explicit mappings for exercises where the seed's `equipment` tags are not enough for correct UX.
enum ExerciseLoadTrackingOverrides {
    static let map: [String: LoadTrackingMode] = [
        "ab_wheel_rollout": .none,
        "battle_ropes": .none,
        "bird_dog": .none,
        "dead_bug": .none,
        "glute_bridge": .supported,
        "mountain_climber": .none,
        "plank": .optional,
        "push_up": .supported,
        "russian_twist": .supported,
        "side_plank": .optional,
        "sled_push": .required,

        "chin_up": .supported,
        "pull_up": .supported,
        "dips": .supported,
        "inverted_row": .optional,
        "calf_raise": .supported,
        "walking_lunge": .supported
    ]
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
    var targetDurationSeconds: Int?
    var targetDistanceMeters: Double?
    var isWarmup: Bool
    var isMaxEffort: Bool
    var isCooldown: Bool

    enum CodingKeys: String, CodingKey {
        case id, targetRepsMin, targetRepsMax, targetWeightKg, rpeTarget
        case targetDurationSeconds, targetDistanceMeters
        case isWarmup, isMaxEffort, isCooldown
    }

    init(
        id: UUID = UUID(),
        targetRepsMin: Int,
        targetRepsMax: Int,
        targetWeightKg: Double? = nil,
        rpeTarget: Double? = nil,
        targetDurationSeconds: Int? = nil,
        targetDistanceMeters: Double? = nil,
        isWarmup: Bool = false,
        isMaxEffort: Bool = false,
        isCooldown: Bool = false
    ) {
        self.id = id
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
        self.targetWeightKg = targetWeightKg
        self.rpeTarget = rpeTarget
        self.targetDurationSeconds = targetDurationSeconds
        self.targetDistanceMeters = targetDistanceMeters
        self.isWarmup = isWarmup
        self.isMaxEffort = isMaxEffort
        self.isCooldown = isCooldown
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        targetRepsMin = try container.decode(Int.self, forKey: .targetRepsMin)
        targetRepsMax = try container.decode(Int.self, forKey: .targetRepsMax)
        targetWeightKg = try container.decodeIfPresent(Double.self, forKey: .targetWeightKg)
        rpeTarget = try container.decodeIfPresent(Double.self, forKey: .rpeTarget)
        targetDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .targetDurationSeconds)
        targetDistanceMeters = try container.decodeIfPresent(Double.self, forKey: .targetDistanceMeters)
        isWarmup = try container.decodeIfPresent(Bool.self, forKey: .isWarmup) ?? false
        isMaxEffort = try container.decodeIfPresent(Bool.self, forKey: .isMaxEffort) ?? false
        isCooldown = try container.decodeIfPresent(Bool.self, forKey: .isCooldown) ?? false
    }
}

struct CompletedSet: Identifiable, Codable, Hashable {
    let id: UUID
    var setIndex: Int
    var weightKg: Double?
    var reps: Int
    var rpe: Double?
    var rir: Int?
    var durationSeconds: Int?
    var distanceMeters: Double?
    var completedAt: Date
    var isWarmup: Bool
    var isFailure: Bool
    var isCooldown: Bool

    enum CodingKeys: String, CodingKey {
        case id, setIndex, weightKg, reps, rpe, rir, durationSeconds, distanceMeters
        case completedAt, isWarmup, isFailure, isCooldown
    }

    init(
        id: UUID = UUID(),
        setIndex: Int,
        weightKg: Double? = nil,
        reps: Int = 0,
        rpe: Double? = nil,
        rir: Int? = nil,
        durationSeconds: Int? = nil,
        distanceMeters: Double? = nil,
        completedAt: Date = Date(),
        isWarmup: Bool = false,
        isFailure: Bool = false,
        isCooldown: Bool = false
    ) {
        self.id = id
        self.setIndex = setIndex
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.rir = rir
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.completedAt = completedAt
        self.isWarmup = isWarmup
        self.isFailure = isFailure
        self.isCooldown = isCooldown
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        setIndex = try container.decode(Int.self, forKey: .setIndex)
        weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg)
        reps = try container.decode(Int.self, forKey: .reps)
        rpe = try container.decodeIfPresent(Double.self, forKey: .rpe)
        rir = try container.decodeIfPresent(Int.self, forKey: .rir)
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
        distanceMeters = try container.decodeIfPresent(Double.self, forKey: .distanceMeters)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        isWarmup = try container.decodeIfPresent(Bool.self, forKey: .isWarmup) ?? false
        isFailure = try container.decodeIfPresent(Bool.self, forKey: .isFailure) ?? false
        isCooldown = try container.decodeIfPresent(Bool.self, forKey: .isCooldown) ?? false
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
    var groupId: UUID?

    init(
        id: UUID = UUID(),
        exerciseId: String,
        orderIndex: Int,
        targetSets: [PlannedSet],
        restSeconds: Int = 90,
        intensity: IntensityTarget = .moderate,
        reason: String = "",
        groupId: UUID? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.orderIndex = orderIndex
        self.targetSets = targetSets
        self.restSeconds = restSeconds
        self.intensity = intensity
        self.reason = reason
        self.groupId = groupId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        exerciseId = try container.decode(String.self, forKey: .exerciseId)
        orderIndex = try container.decode(Int.self, forKey: .orderIndex)
        targetSets = try container.decode([PlannedSet].self, forKey: .targetSets)
        restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 90
        intensity = try container.decodeIfPresent(IntensityTarget.self, forKey: .intensity) ?? .moderate
        reason = try container.decodeIfPresent(String.self, forKey: .reason) ?? ""
        groupId = try container.decodeIfPresent(UUID.self, forKey: .groupId)
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
    var selectionRationale: [String]
    var safetyNotes: [String]
    var generatedBy: WorkoutGenerationSource
    var createdAt: Date
    var sessionMode: SessionMode = .standard
    var splitDayFocus: SplitDayFocus?

    enum CodingKeys: String, CodingKey {
        case id, title, estimatedDurationMinutes, focus, exercises, rationale
        case selectionRationale, safetyNotes, generatedBy, createdAt, sessionMode, splitDayFocus
    }

    init(
        id: UUID,
        title: String,
        estimatedDurationMinutes: Int,
        focus: [MuscleGroup],
        exercises: [PlannedExercise],
        rationale: String,
        selectionRationale: [String] = [],
        safetyNotes: [String],
        generatedBy: WorkoutGenerationSource,
        createdAt: Date,
        sessionMode: SessionMode = .standard,
        splitDayFocus: SplitDayFocus? = nil
    ) {
        self.id = id
        self.title = title
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.focus = focus
        self.exercises = exercises
        self.rationale = rationale
        self.selectionRationale = selectionRationale
        self.safetyNotes = safetyNotes
        self.generatedBy = generatedBy
        self.createdAt = createdAt
        self.sessionMode = sessionMode
        self.splitDayFocus = splitDayFocus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        estimatedDurationMinutes = try container.decode(Int.self, forKey: .estimatedDurationMinutes)
        focus = try container.decode([MuscleGroup].self, forKey: .focus)
        exercises = try container.decode([PlannedExercise].self, forKey: .exercises)
        rationale = try container.decode(String.self, forKey: .rationale)
        selectionRationale = try container.decodeIfPresent([String].self, forKey: .selectionRationale) ?? []
        safetyNotes = try container.decode([String].self, forKey: .safetyNotes)
        generatedBy = try container.decode(WorkoutGenerationSource.self, forKey: .generatedBy)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        sessionMode = try container.decodeIfPresent(SessionMode.self, forKey: .sessionMode) ?? .standard
        splitDayFocus = try container.decodeIfPresent(SplitDayFocus.self, forKey: .splitDayFocus)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(estimatedDurationMinutes, forKey: .estimatedDurationMinutes)
        try container.encode(focus, forKey: .focus)
        try container.encode(exercises, forKey: .exercises)
        try container.encode(rationale, forKey: .rationale)
        try container.encode(selectionRationale, forKey: .selectionRationale)
        try container.encode(safetyNotes, forKey: .safetyNotes)
        try container.encode(generatedBy, forKey: .generatedBy)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(sessionMode, forKey: .sessionMode)
        try container.encodeIfPresent(splitDayFocus, forKey: .splitDayFocus)
    }
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
    var groupId: UUID?

    init(
        id: UUID = UUID(),
        exerciseId: String,
        orderIndex: Int,
        plannedSets: [PlannedSet],
        completedSets: [CompletedSet] = [],
        restSeconds: Int = 90,
        notes: String? = nil,
        wasSkipped: Bool = false,
        skipReason: String? = nil,
        groupId: UUID? = nil
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
        self.groupId = groupId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        exerciseId = try container.decode(String.self, forKey: .exerciseId)
        orderIndex = try container.decode(Int.self, forKey: .orderIndex)
        plannedSets = try container.decode([PlannedSet].self, forKey: .plannedSets)
        completedSets = try container.decodeIfPresent([CompletedSet].self, forKey: .completedSets) ?? []
        restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 90
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        wasSkipped = try container.decodeIfPresent(Bool.self, forKey: .wasSkipped) ?? false
        skipReason = try container.decodeIfPresent(String.self, forKey: .skipReason)
        groupId = try container.decodeIfPresent(UUID.self, forKey: .groupId)
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
    var splitDayFocus: SplitDayFocus?
    var activeRestEndAt: Date?
    var activeRestTotalSeconds: Int?
    var activeRestAdvancesExercise: Bool?

    enum CodingKeys: String, CodingKey {
        case id, userId, title, startedAt, completedAt, estimatedDurationMinutes
        case exercises, notes, perceivedDifficulty, status, splitDayFocus
        case activeRestEndAt, activeRestTotalSeconds, activeRestAdvancesExercise
    }

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
        status: WorkoutStatus = .planned,
        splitDayFocus: SplitDayFocus? = nil,
        activeRestEndAt: Date? = nil,
        activeRestTotalSeconds: Int? = nil,
        activeRestAdvancesExercise: Bool? = nil
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
        self.splitDayFocus = splitDayFocus
        self.activeRestEndAt = activeRestEndAt
        self.activeRestTotalSeconds = activeRestTotalSeconds
        self.activeRestAdvancesExercise = activeRestAdvancesExercise
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        title = try container.decode(String.self, forKey: .title)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        estimatedDurationMinutes = try container.decode(Int.self, forKey: .estimatedDurationMinutes)
        exercises = try container.decode([WorkoutExercise].self, forKey: .exercises)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        perceivedDifficulty = try container.decodeIfPresent(Int.self, forKey: .perceivedDifficulty)
        status = try container.decode(WorkoutStatus.self, forKey: .status)
        splitDayFocus = try container.decodeIfPresent(SplitDayFocus.self, forKey: .splitDayFocus)
        activeRestEndAt = try container.decodeIfPresent(Date.self, forKey: .activeRestEndAt)
        activeRestTotalSeconds = try container.decodeIfPresent(Int.self, forKey: .activeRestTotalSeconds)
        activeRestAdvancesExercise = try container.decodeIfPresent(Bool.self, forKey: .activeRestAdvancesExercise)
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
    var goalAtLastUpdate: TrainingGoal?

    // Volume tracking (last 12 weeks of weekly volume in reps)
    var weeklyVolume: [Int] = []
    var weeklyMaxSets: Int = 0
    var volumeTrend: TrendDirection = .stable

    // Deload tracking — dated state; active for 7 rolling days from start
    var deloadStartedAt: Date?
    var returningFromBreak: Bool = false
    var consecutiveHighVolumeWeeks: Int = 0
    var isOrphaned: Bool = false
    var lastMaxEffortAt: Date?
    var sessionsSinceMaxEffort: Int = 0

    var id: String { exerciseId }

    var preferredRepRange: ClosedRange<Int> {
        preferredRepRangeMin...preferredRepRangeMax
    }

    var planningWeightKg: Double? {
        suggestedNextWeightKg ?? lastWeightKg
    }

    func isInDeloadWeek(at now: Date = Date()) -> Bool {
        guard let start = deloadStartedAt else { return false }
        return now.timeIntervalSince(start) < GenerationConstants.Time.rollingWindowSeconds
    }

    var isInDeloadWeek: Bool { isInDeloadWeek(at: Date()) }

    /// Suppresses volume-drop deload detection during deload and the week after.
    func isInDeloadSuppressionWindow(at now: Date = Date()) -> Bool {
        guard let start = deloadStartedAt else { return false }
        return now.timeIntervalSince(start) < 2 * GenerationConstants.Time.rollingWindowSeconds
    }

    enum CodingKeys: String, CodingKey {
        case exerciseId, lastWeightKg, lastReps, suggestedNextWeightKg, estimatedOneRepMax
        case bestVolumeSet, recentSets, preferredRepRangeMin, preferredRepRangeMax
        case goalAtLastUpdate, deloadStartedAt, returningFromBreak
        case weeklyVolume, weeklyMaxSets, volumeTrend, consecutiveHighVolumeWeeks, isOrphaned
        case lastMaxEffortAt, sessionsSinceMaxEffort
        case legacyIsInDeloadWeek = "isInDeloadWeek"
        case legacyLastDeloadDate = "lastDeloadDate"
    }

    init(
        exerciseId: String,
        lastWeightKg: Double? = nil,
        lastReps: Int? = nil,
        suggestedNextWeightKg: Double? = nil,
        estimatedOneRepMax: Double? = nil,
        bestVolumeSet: Double? = nil,
        recentSets: [CompletedSet] = [],
        preferredRepRangeMin: Int,
        preferredRepRangeMax: Int,
        goalAtLastUpdate: TrainingGoal? = nil,
        deloadStartedAt: Date? = nil,
        returningFromBreak: Bool = false,
        lastMaxEffortAt: Date? = nil,
        sessionsSinceMaxEffort: Int = 0
    ) {
        self.exerciseId = exerciseId
        self.lastWeightKg = lastWeightKg
        self.lastReps = lastReps
        self.suggestedNextWeightKg = suggestedNextWeightKg
        self.estimatedOneRepMax = estimatedOneRepMax
        self.bestVolumeSet = bestVolumeSet
        self.recentSets = recentSets
        self.preferredRepRangeMin = preferredRepRangeMin
        self.preferredRepRangeMax = preferredRepRangeMax
        self.goalAtLastUpdate = goalAtLastUpdate
        self.deloadStartedAt = deloadStartedAt
        self.returningFromBreak = returningFromBreak
        self.lastMaxEffortAt = lastMaxEffortAt
        self.sessionsSinceMaxEffort = sessionsSinceMaxEffort
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exerciseId = try container.decode(String.self, forKey: .exerciseId)
        lastWeightKg = try container.decodeIfPresent(Double.self, forKey: .lastWeightKg)
        lastReps = try container.decodeIfPresent(Int.self, forKey: .lastReps)
        suggestedNextWeightKg = try container.decodeIfPresent(Double.self, forKey: .suggestedNextWeightKg)
        estimatedOneRepMax = try container.decodeIfPresent(Double.self, forKey: .estimatedOneRepMax)
        bestVolumeSet = try container.decodeIfPresent(Double.self, forKey: .bestVolumeSet)
        recentSets = try container.decodeIfPresent([CompletedSet].self, forKey: .recentSets) ?? []
        preferredRepRangeMin = try container.decode(Int.self, forKey: .preferredRepRangeMin)
        preferredRepRangeMax = try container.decode(Int.self, forKey: .preferredRepRangeMax)
        goalAtLastUpdate = try container.decodeIfPresent(TrainingGoal.self, forKey: .goalAtLastUpdate)
        deloadStartedAt = try container.decodeIfPresent(Date.self, forKey: .deloadStartedAt)
        if deloadStartedAt == nil,
           try container.decodeIfPresent(Bool.self, forKey: .legacyIsInDeloadWeek) == true {
            deloadStartedAt = try container.decodeIfPresent(Date.self, forKey: .legacyLastDeloadDate) ?? Date()
        }
        returningFromBreak = try container.decodeIfPresent(Bool.self, forKey: .returningFromBreak) ?? false
        weeklyVolume = try container.decodeIfPresent([Int].self, forKey: .weeklyVolume) ?? []
        weeklyMaxSets = try container.decodeIfPresent(Int.self, forKey: .weeklyMaxSets) ?? 0
        volumeTrend = try container.decodeIfPresent(TrendDirection.self, forKey: .volumeTrend) ?? .stable
        consecutiveHighVolumeWeeks = try container.decodeIfPresent(Int.self, forKey: .consecutiveHighVolumeWeeks) ?? 0
        isOrphaned = try container.decodeIfPresent(Bool.self, forKey: .isOrphaned) ?? false
        lastMaxEffortAt = try container.decodeIfPresent(Date.self, forKey: .lastMaxEffortAt)
        sessionsSinceMaxEffort = try container.decodeIfPresent(Int.self, forKey: .sessionsSinceMaxEffort) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(exerciseId, forKey: .exerciseId)
        try container.encodeIfPresent(lastWeightKg, forKey: .lastWeightKg)
        try container.encodeIfPresent(lastReps, forKey: .lastReps)
        try container.encodeIfPresent(suggestedNextWeightKg, forKey: .suggestedNextWeightKg)
        try container.encodeIfPresent(estimatedOneRepMax, forKey: .estimatedOneRepMax)
        try container.encodeIfPresent(bestVolumeSet, forKey: .bestVolumeSet)
        try container.encode(recentSets, forKey: .recentSets)
        try container.encode(preferredRepRangeMin, forKey: .preferredRepRangeMin)
        try container.encode(preferredRepRangeMax, forKey: .preferredRepRangeMax)
        try container.encodeIfPresent(goalAtLastUpdate, forKey: .goalAtLastUpdate)
        try container.encodeIfPresent(deloadStartedAt, forKey: .deloadStartedAt)
        try container.encode(returningFromBreak, forKey: .returningFromBreak)
        try container.encode(weeklyVolume, forKey: .weeklyVolume)
        try container.encode(weeklyMaxSets, forKey: .weeklyMaxSets)
        try container.encode(volumeTrend, forKey: .volumeTrend)
        try container.encode(consecutiveHighVolumeWeeks, forKey: .consecutiveHighVolumeWeeks)
        try container.encode(isOrphaned, forKey: .isOrphaned)
        try container.encodeIfPresent(lastMaxEffortAt, forKey: .lastMaxEffortAt)
        try container.encode(sessionsSinceMaxEffort, forKey: .sessionsSinceMaxEffort)
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
    var exerciseVariability: ExerciseVariabilityLevel = .balanced
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isValid = try container.decode(Bool.self, forKey: .isValid)
        errors = try container.decode([String].self, forKey: .errors)
        warnings = try container.decode([String].self, forKey: .warnings)
        suggestions = try container.decodeIfPresent([String].self, forKey: .suggestions) ?? []
    }
}

enum GenerationFailure: Error, Equatable {
    case insufficientExercises(available: Int, blockedByInjury: Int, blockedByEquipment: Int)
    case planValidationFailed(summary: String)

    var userMessage: String {
        switch self {
        case let .insufficientExercises(available, _, _):
            "Your equipment and injury settings leave only \(available) exercises — add equipment or review limitations."
        case let .planValidationFailed(summary):
            summary
        }
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
