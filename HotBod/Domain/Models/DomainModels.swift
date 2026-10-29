// swiftlint:disable file_length
import Foundation

enum BodyMassSource: String, Codable, Hashable {
    case health
    case manual
}

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
    var preferredSessionLengthMinutes: Int
    var preferredSplit: TrainingSplit
    /// Usual training days — drives local reminders and soft Recovery framing (not a generation gate).
    var reminderTrainingDays: [Weekday]
    var timeOfDayPreference: TimeOfDayPreference
    /// When true, schedule local workout reminders on `reminderTrainingDays`.
    var workoutRemindersEnabled: Bool
    var limitations: [BodyLimitation]
    var limitationNotes: String?
    var preferredMuscleGroups: [MuscleGroup]?
    var avoidedMuscleGroups: [MuscleGroup]?
    var proteinGoalGrams: Double
    var photoTrackingEnabled: Bool
    var includeWarmupSets: Bool
    /// Mobility stretches prepended to the session. Distinct from ramping warm-up sets.
    var includeWarmupStretches: Bool
    var includeCooldown: Bool
    var preferredExerciseGrouping: ExerciseGroupingPreference
    var preferredExerciseVariability: ExerciseVariabilityLevel
    var cardioBlockPlacement: CardioBlockPlacement
    var includeConditioning: Bool
    var includeCoreFinisher: Bool
    var promptForEffortFeedback: Bool
    var trustHistoricEffortFeedback: Bool
    var maxAvailableWeightKg: [Equipment: Double]
    var exportWorkoutsToHealthKit: Bool
    /// Nil until Apple Health or a manual edit chooses the source of `weightKg`.
    var bodyMassSource: BodyMassSource?
    /// When the user last typed a weight. Health samples at or before this time stay ignored.
    var bodyMassLockedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    /// Derived from `reminderTrainingDays` — not persisted as an independent source of truth.
    var trainingDaysPerWeek: Int { max(reminderTrainingDays.count, 0) }

    enum CodingKeys: String, CodingKey {
        case id, name, age, goal, limitations, limitationNotes
        case heightCm, weightKg, experienceLevel, trainingLocation, availableEquipment
        case trainingDaysPerWeek, preferredSessionLengthMinutes, preferredSplit
        case reminderTrainingDays, preferredTrainingDays
        case timeOfDayPreference, workoutRemindersEnabled
        case preferredMuscleGroups, avoidedMuscleGroups
        case proteinGoalGrams, photoTrackingEnabled, includeWarmupSets, includeWarmupStretches, includeCooldown
        case preferredExerciseGrouping, preferredExerciseVariability, cardioBlockPlacement
        case includeConditioning, includeCoreFinisher
        case promptForEffortFeedback, trustHistoricEffortFeedback
        case maxAvailableWeightKg
        case exportWorkoutsToHealthKit
        case bodyMassSource, bodyMassLockedAt
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
        preferredSessionLengthMinutes: Int,
        preferredSplit: TrainingSplit,
        reminderTrainingDays: [Weekday],
        timeOfDayPreference: TimeOfDayPreference,
        workoutRemindersEnabled: Bool = true,
        limitations: [BodyLimitation],
        limitationNotes: String? = nil,
        preferredMuscleGroups: [MuscleGroup]? = nil,
        avoidedMuscleGroups: [MuscleGroup]? = nil,
        proteinGoalGrams: Double,
        photoTrackingEnabled: Bool,
        includeWarmupSets: Bool = true,
        includeWarmupStretches: Bool = false,
        includeCooldown: Bool = false,
        preferredExerciseGrouping: ExerciseGroupingPreference = .none,
        preferredExerciseVariability: ExerciseVariabilityLevel = .balanced,
        cardioBlockPlacement: CardioBlockPlacement = .none,
        includeConditioning: Bool = false,
        includeCoreFinisher: Bool = true,
        promptForEffortFeedback: Bool = true,
        trustHistoricEffortFeedback: Bool = true,
        maxAvailableWeightKg: [Equipment: Double] = [:],
        exportWorkoutsToHealthKit: Bool = false,
        bodyMassSource: BodyMassSource? = nil,
        bodyMassLockedAt: Date? = nil,
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
        self.preferredSessionLengthMinutes = preferredSessionLengthMinutes
        self.preferredSplit = preferredSplit
        self.reminderTrainingDays = reminderTrainingDays
        self.timeOfDayPreference = timeOfDayPreference
        self.workoutRemindersEnabled = workoutRemindersEnabled
        self.limitations = limitations
        self.limitationNotes = limitationNotes
        self.preferredMuscleGroups = preferredMuscleGroups
        self.avoidedMuscleGroups = avoidedMuscleGroups
        self.proteinGoalGrams = proteinGoalGrams
        self.photoTrackingEnabled = photoTrackingEnabled
        self.includeWarmupSets = includeWarmupSets
        self.includeWarmupStretches = includeWarmupStretches
        self.includeCooldown = includeCooldown
        self.preferredExerciseGrouping = preferredExerciseGrouping
        self.preferredExerciseVariability = preferredExerciseVariability
        self.cardioBlockPlacement = cardioBlockPlacement
        self.includeConditioning = includeConditioning
        self.includeCoreFinisher = includeCoreFinisher
        self.promptForEffortFeedback = promptForEffortFeedback
        self.trustHistoricEffortFeedback = trustHistoricEffortFeedback
        self.maxAvailableWeightKg = maxAvailableWeightKg
        self.exportWorkoutsToHealthKit = exportWorkoutsToHealthKit
        self.bodyMassSource = bodyMassSource
        self.bodyMassLockedAt = bodyMassLockedAt
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
        preferredSessionLengthMinutes = try container.decode(Int.self, forKey: .preferredSessionLengthMinutes)
        preferredSplit = try container.decode(TrainingSplit.self, forKey: .preferredSplit)
        if let modern = try container.decodeIfPresent([Weekday].self, forKey: .reminderTrainingDays) {
            reminderTrainingDays = modern
        } else if let legacy = try container.decodeIfPresent([Weekday].self, forKey: .preferredTrainingDays) {
            reminderTrainingDays = legacy
        } else {
            reminderTrainingDays = [.monday, .tuesday, .thursday, .friday]
        }
        // Legacy independent frequency is ignored; days list is source of truth.
        _ = try container.decodeIfPresent(Int.self, forKey: .trainingDaysPerWeek)
        timeOfDayPreference = try container.decode(TimeOfDayPreference.self, forKey: .timeOfDayPreference)
        workoutRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .workoutRemindersEnabled) ?? true
        limitations = try container.decode([BodyLimitation].self, forKey: .limitations)
        limitationNotes = try container.decodeIfPresent(String.self, forKey: .limitationNotes)
        preferredMuscleGroups = try container.decodeIfPresent([MuscleGroup].self, forKey: .preferredMuscleGroups)
        avoidedMuscleGroups = try container.decodeIfPresent([MuscleGroup].self, forKey: .avoidedMuscleGroups)
        proteinGoalGrams = try container.decode(Double.self, forKey: .proteinGoalGrams)
        photoTrackingEnabled = try container.decode(Bool.self, forKey: .photoTrackingEnabled)
        includeWarmupSets = try container.decodeIfPresent(Bool.self, forKey: .includeWarmupSets) ?? true
        includeWarmupStretches = try container.decodeIfPresent(Bool.self, forKey: .includeWarmupStretches) ?? false
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
        promptForEffortFeedback = try container.decodeIfPresent(Bool.self, forKey: .promptForEffortFeedback) ?? true
        trustHistoricEffortFeedback = try container.decodeIfPresent(
            Bool.self,
            forKey: .trustHistoricEffortFeedback
        ) ?? true
        maxAvailableWeightKg = try container.decodeIfPresent([Equipment: Double].self, forKey: .maxAvailableWeightKg) ?? [:]
        exportWorkoutsToHealthKit = try container.decodeIfPresent(Bool.self, forKey: .exportWorkoutsToHealthKit) ?? false
        bodyMassSource = try container.decodeIfPresent(BodyMassSource.self, forKey: .bodyMassSource)
        bodyMassLockedAt = try container.decodeIfPresent(Date.self, forKey: .bodyMassLockedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(age, forKey: .age)
        try container.encodeIfPresent(heightCm, forKey: .heightCm)
        try container.encodeIfPresent(weightKg, forKey: .weightKg)
        try container.encode(goal, forKey: .goal)
        try container.encode(experienceLevel, forKey: .experienceLevel)
        try container.encode(trainingLocation, forKey: .trainingLocation)
        try container.encode(availableEquipment, forKey: .availableEquipment)
        try container.encode(trainingDaysPerWeek, forKey: .trainingDaysPerWeek)
        try container.encode(preferredSessionLengthMinutes, forKey: .preferredSessionLengthMinutes)
        try container.encode(preferredSplit, forKey: .preferredSplit)
        try container.encode(reminderTrainingDays, forKey: .reminderTrainingDays)
        try container.encode(timeOfDayPreference, forKey: .timeOfDayPreference)
        try container.encode(workoutRemindersEnabled, forKey: .workoutRemindersEnabled)
        try container.encode(limitations, forKey: .limitations)
        try container.encodeIfPresent(limitationNotes, forKey: .limitationNotes)
        try container.encodeIfPresent(preferredMuscleGroups, forKey: .preferredMuscleGroups)
        try container.encodeIfPresent(avoidedMuscleGroups, forKey: .avoidedMuscleGroups)
        try container.encode(proteinGoalGrams, forKey: .proteinGoalGrams)
        try container.encode(photoTrackingEnabled, forKey: .photoTrackingEnabled)
        try container.encode(includeWarmupSets, forKey: .includeWarmupSets)
        try container.encode(includeWarmupStretches, forKey: .includeWarmupStretches)
        try container.encode(includeCooldown, forKey: .includeCooldown)
        try container.encode(preferredExerciseGrouping, forKey: .preferredExerciseGrouping)
        try container.encode(preferredExerciseVariability, forKey: .preferredExerciseVariability)
        try container.encode(cardioBlockPlacement, forKey: .cardioBlockPlacement)
        try container.encode(includeConditioning, forKey: .includeConditioning)
        try container.encode(includeCoreFinisher, forKey: .includeCoreFinisher)
        try container.encode(promptForEffortFeedback, forKey: .promptForEffortFeedback)
        try container.encode(trustHistoricEffortFeedback, forKey: .trustHistoricEffortFeedback)
        try container.encode(maxAvailableWeightKg, forKey: .maxAvailableWeightKg)
        try container.encode(exportWorkoutsToHealthKit, forKey: .exportWorkoutsToHealthKit)
        try container.encodeIfPresent(bodyMassSource, forKey: .bodyMassSource)
        try container.encodeIfPresent(bodyMassLockedAt, forKey: .bodyMassLockedAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    static func empty() -> UserProfile {
        UserProfile(
            id: UUID(),
            goal: .buildMuscle,
            experienceLevel: .intermediate,
            trainingLocation: .commercialGym,
            availableEquipment: Equipment.allCases,
            preferredSessionLengthMinutes: 45,
            preferredSplit: .upperLower,
            reminderTrainingDays: [.monday, .tuesday, .thursday, .friday],
            timeOfDayPreference: .flexible,
            workoutRemindersEnabled: true,
            limitations: [.none],
            preferredMuscleGroups: [],
            avoidedMuscleGroups: [],
            proteinGoalGrams: 145,
            photoTrackingEnabled: false,
            includeWarmupSets: true,
            includeWarmupStretches: false,
            includeCooldown: false,
            preferredExerciseGrouping: .none,
            preferredExerciseVariability: .balanced,
            cardioBlockPlacement: .none,
            promptForEffortFeedback: true,
            trustHistoricEffortFeedback: true,
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
            preferredSessionLengthMinutes: preferredSessionLengthMinutes,
            preferredSplit: preferredSplit,
            reminderTrainingDays: reminderTrainingDays,
            timeOfDayPreference: timeOfDayPreference,
            workoutRemindersEnabled: workoutRemindersEnabled,
            limitations: limitations,
            limitationNotes: limitationNotes,
            preferredMuscleGroups: preferredMuscleGroups,
            avoidedMuscleGroups: avoidedMuscleGroups,
            proteinGoalGrams: proteinGoalGrams,
            photoTrackingEnabled: photoTrackingEnabled,
            includeWarmupSets: includeWarmupSets,
            includeWarmupStretches: includeWarmupStretches,
            includeCooldown: includeCooldown,
            preferredExerciseGrouping: preferredExerciseGrouping,
            preferredExerciseVariability: preferredExerciseVariability,
            cardioBlockPlacement: cardioBlockPlacement,
            includeConditioning: includeConditioning,
            includeCoreFinisher: includeCoreFinisher,
            promptForEffortFeedback: promptForEffortFeedback,
            trustHistoricEffortFeedback: trustHistoricEffortFeedback,
            maxAvailableWeightKg: maxAvailableWeightKg,
            exportWorkoutsToHealthKit: exportWorkoutsToHealthKit,
            bodyMassSource: bodyMassSource,
            bodyMassLockedAt: bodyMassLockedAt,
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

    /// Kilogram target to store on a planned set. Resistance-level machines stay unset
    /// so a generated kilogram guess is not shown as a damper setting.
    func plannedExternalLoadKg(_ candidate: Double?, hasLoggedWeight: Bool) -> Double? {
        guard resolvedWeightDisplaySemantics.tracksExternalKilograms else { return nil }
        guard resolvedLoadTrackingMode.plansExternalLoad(hasLoggedWeight: hasLoggedWeight) else { return nil }
        return candidate
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

enum EffortFeedbackStatus: String, Codable, Hashable {
    case explicit
    case skipped
    case unknown
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
    var effortFeedbackStatus: EffortFeedbackStatus = .unknown

    enum CodingKeys: String, CodingKey {
        case id, setIndex, weightKg, reps, rpe, rir, durationSeconds, distanceMeters
        case completedAt, isWarmup, isFailure, isCooldown, effortFeedbackStatus
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
        isCooldown: Bool = false,
        effortFeedbackStatus: EffortFeedbackStatus = .unknown
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
        self.effortFeedbackStatus = effortFeedbackStatus
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
        effortFeedbackStatus = try container.decodeIfPresent(
            EffortFeedbackStatus.self, forKey: .effortFeedbackStatus
        ) ?? .unknown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(setIndex, forKey: .setIndex)
        try container.encodeIfPresent(weightKg, forKey: .weightKg)
        try container.encode(reps, forKey: .reps)
        try container.encodeIfPresent(rpe, forKey: .rpe)
        try container.encodeIfPresent(rir, forKey: .rir)
        try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
        try container.encodeIfPresent(distanceMeters, forKey: .distanceMeters)
        try container.encode(completedAt, forKey: .completedAt)
        try container.encode(isWarmup, forKey: .isWarmup)
        try container.encode(isFailure, forKey: .isFailure)
        try container.encode(isCooldown, forKey: .isCooldown)
        try container.encode(effortFeedbackStatus, forKey: .effortFeedbackStatus)
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
    var sessionMode: SessionMode = .standard
    /// Set after fatigue, stats, and program advance have been applied for this session.
    var progressionAppliedAt: Date?
    var activeRestEndAt: Date?
    var activeRestTotalSeconds: Int?
    var activeRestAdvancesExercise: Bool?
    /// Workout exercise the athlete was on. Resume uses this instead of the first unfinished exercise.
    var currentExerciseId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, userId, title, startedAt, completedAt, estimatedDurationMinutes
        case exercises, notes, perceivedDifficulty, status, splitDayFocus, sessionMode
        case progressionAppliedAt
        case activeRestEndAt, activeRestTotalSeconds, activeRestAdvancesExercise
        case currentExerciseId
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
        sessionMode: SessionMode = .standard,
        progressionAppliedAt: Date? = nil,
        activeRestEndAt: Date? = nil,
        activeRestTotalSeconds: Int? = nil,
        activeRestAdvancesExercise: Bool? = nil,
        currentExerciseId: UUID? = nil
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
        self.sessionMode = sessionMode
        self.progressionAppliedAt = progressionAppliedAt
        self.activeRestEndAt = activeRestEndAt
        self.activeRestTotalSeconds = activeRestTotalSeconds
        self.activeRestAdvancesExercise = activeRestAdvancesExercise
        self.currentExerciseId = currentExerciseId
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
        sessionMode = try container.decodeIfPresent(SessionMode.self, forKey: .sessionMode) ?? .standard
        progressionAppliedAt = try container.decodeIfPresent(Date.self, forKey: .progressionAppliedAt)
        activeRestEndAt = try container.decodeIfPresent(Date.self, forKey: .activeRestEndAt)
        activeRestTotalSeconds = try container.decodeIfPresent(Int.self, forKey: .activeRestTotalSeconds)
        activeRestAdvancesExercise = try container.decodeIfPresent(Bool.self, forKey: .activeRestAdvancesExercise)
        currentExerciseId = try container.decodeIfPresent(UUID.self, forKey: .currentExerciseId)
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
    /// Stall signal: next generate should bias away from this exercise.
    var preferVariation: Bool = false
    var updatedAt: Date?

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
        case lastMaxEffortAt, sessionsSinceMaxEffort, preferVariation, updatedAt
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
        sessionsSinceMaxEffort: Int = 0,
        preferVariation: Bool = false
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
        self.preferVariation = preferVariation
        self.updatedAt = nil
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
        preferVariation = try container.decodeIfPresent(Bool.self, forKey: .preferVariation) ?? false
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
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
        try container.encode(preferVariation, forKey: .preferVariation)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
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
    let physiquePreferredMuscleGroups: [MuscleGroup]
    let avoidedMuscleGroups: [MuscleGroup]
    let injuries: [BodyLimitation]
    let recentWorkouts: [WorkoutSessionSummary]
    let muscleRecovery: [MuscleGroup: Double]
    let exerciseStats: [UserExerciseStats]
    let userPreferences: WorkoutPreferences
    let readiness: ReadinessInput?
    let splitDayFocus: SplitDayFocus?
    let forceRecoverySession: Bool

    init(
        userProfile: UserProfile,
        goal: TrainingGoal,
        experienceLevel: ExperienceLevel,
        availableEquipment: [Equipment],
        targetDurationMinutes: Int,
        preferredMuscleGroups: [MuscleGroup],
        physiquePreferredMuscleGroups: [MuscleGroup] = [],
        avoidedMuscleGroups: [MuscleGroup],
        injuries: [BodyLimitation],
        recentWorkouts: [WorkoutSessionSummary],
        muscleRecovery: [MuscleGroup: Double],
        exerciseStats: [UserExerciseStats],
        userPreferences: WorkoutPreferences,
        readiness: ReadinessInput?,
        splitDayFocus: SplitDayFocus?,
        forceRecoverySession: Bool = false
    ) {
        self.userProfile = userProfile
        self.goal = goal
        self.experienceLevel = experienceLevel
        self.availableEquipment = availableEquipment
        self.targetDurationMinutes = targetDurationMinutes
        self.preferredMuscleGroups = preferredMuscleGroups
        self.physiquePreferredMuscleGroups = physiquePreferredMuscleGroups
        self.avoidedMuscleGroups = avoidedMuscleGroups
        self.injuries = injuries
        self.recentWorkouts = recentWorkouts
        self.muscleRecovery = muscleRecovery
        self.exerciseStats = exerciseStats
        self.userPreferences = userPreferences
        self.readiness = readiness
        self.splitDayFocus = splitDayFocus
        self.forceRecoverySession = forceRecoverySession
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userProfile = try container.decode(UserProfile.self, forKey: .userProfile)
        goal = try container.decode(TrainingGoal.self, forKey: .goal)
        experienceLevel = try container.decode(ExperienceLevel.self, forKey: .experienceLevel)
        availableEquipment = try container.decode([Equipment].self, forKey: .availableEquipment)
        targetDurationMinutes = try container.decode(Int.self, forKey: .targetDurationMinutes)
        preferredMuscleGroups = try container.decode([MuscleGroup].self, forKey: .preferredMuscleGroups)
        physiquePreferredMuscleGroups = try container.decodeIfPresent(
            [MuscleGroup].self,
            forKey: .physiquePreferredMuscleGroups
        ) ?? []
        avoidedMuscleGroups = try container.decode([MuscleGroup].self, forKey: .avoidedMuscleGroups)
        injuries = try container.decode([BodyLimitation].self, forKey: .injuries)
        recentWorkouts = try container.decode([WorkoutSessionSummary].self, forKey: .recentWorkouts)
        muscleRecovery = try container.decode([MuscleGroup: Double].self, forKey: .muscleRecovery)
        exerciseStats = try container.decode([UserExerciseStats].self, forKey: .exerciseStats)
        userPreferences = try container.decode(WorkoutPreferences.self, forKey: .userPreferences)
        readiness = try container.decodeIfPresent(ReadinessInput.self, forKey: .readiness)
        splitDayFocus = try container.decodeIfPresent(SplitDayFocus.self, forKey: .splitDayFocus)
        forceRecoverySession = try container.decodeIfPresent(Bool.self, forKey: .forceRecoverySession) ?? false
    }
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
    case planValidationFailed(summary: String, allowsRecoveryOverride: Bool = false)

    var userMessage: String {
        switch self {
        case let .insufficientExercises(available, _, _):
            "Your equipment and injury settings leave only \(available) exercises — add equipment or review limitations."
        case let .planValidationFailed(summary, _):
            summary
        }
    }

    var allowsRecoveryOverride: Bool {
        switch self {
        case let .planValidationFailed(_, allowsRecoveryOverride):
            allowsRecoveryOverride
        case .insufficientExercises:
            false
        }
    }

    static func isCriticalFatigueError(_ message: String) -> Bool {
        message.contains("Critical fatigue") || message.contains("critically fatigued")
    }

    static func allowsRecoveryOverride(errors: [String]) -> Bool {
        guard !errors.isEmpty else { return false }
        return errors.allSatisfy(isCriticalFatigueError)
    }

    static func planValidationFailed(errors: [String]) -> GenerationFailure {
        .planValidationFailed(
            summary: errors.first ?? "Generated workout did not pass safety checks.",
            allowsRecoveryOverride: allowsRecoveryOverride(errors: errors)
        )
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

