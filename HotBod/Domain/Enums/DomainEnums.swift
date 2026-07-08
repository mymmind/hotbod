import Foundation

enum TrainingGoal: String, Codable, CaseIterable, Identifiable {
    case buildMuscle
    case gainStrength
    case loseFat
    case generalFitness
    case athleticPerformance
    case hybridAthlete

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .buildMuscle: "Build Muscle"
        case .gainStrength: "Gain Strength"
        case .loseFat: "Lose Fat"
        case .generalFitness: "General Fitness"
        case .athleticPerformance: "Athletic Performance"
        case .hybridAthlete: "Hybrid Athlete"
        }
    }
}

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        }
    }

    var description: String {
        switch self {
        case .beginner: "I need guidance on form, weights, and structure."
        case .intermediate: "I train regularly but want better programming."
        case .advanced: "I know what I'm doing and want adaptive optimization."
        }
    }

    var recoveryRatePerHour: Double {
        switch self {
        case .beginner: 2.2
        case .intermediate: 1.8
        case .advanced: 1.5
        }
    }
}

enum TrainingLocation: String, Codable, CaseIterable, Identifiable {
    case commercialGym
    case homeGym
    case bodyweightOnly
    case mixed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .commercialGym: "Commercial Gym"
        case .homeGym: "Home Gym"
        case .bodyweightOnly: "Bodyweight Only"
        case .mixed: "Mixed"
        }
    }
}

enum TrainingSplit: String, Codable, CaseIterable, Identifiable {
    case fullBody
    case upperLower
    case pushPullLegs
    case arnold
    case bodyPart
    case custom
    case adaptive

    var id: String { rawValue }

    /// Splits exposed in onboarding/settings. Placeholder splits remain decodable for legacy profiles.
    static var selectableSplits: [TrainingSplit] {
        [.fullBody, .upperLower, .pushPullLegs, .arnold, .adaptive]
    }

    var displayName: String {
        switch self {
        case .fullBody: "Full Body"
        case .upperLower: "Upper / Lower"
        case .pushPullLegs: "Push / Pull / Legs"
        case .arnold: "Arnold Split"
        case .bodyPart: "Body Part"
        case .custom: "Custom"
        case .adaptive: "Adaptive"
        }
    }
}

enum BodyLimitation: String, Codable, CaseIterable, Identifiable {
    case shoulder
    case elbow
    case wrist
    case lowerBack
    case hip
    case knee
    case ankle
    case neck
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shoulder: "Shoulder"
        case .elbow: "Elbow"
        case .wrist: "Wrist"
        case .lowerBack: "Lower Back"
        case .hip: "Hip"
        case .knee: "Knee"
        case .ankle: "Ankle"
        case .neck: "Neck"
        case .none: "None"
        }
    }
}

enum MuscleGroup: String, Codable, CaseIterable, Identifiable, Hashable {
    case chest, back, shoulders, biceps, triceps, forearms
    case abs, obliques, quads, hamstrings, glutes, calves
    case lowerBack, traps, adductors, abductors

    var id: String { rawValue }

    var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    /// Muscles users can prefer or avoid in workout generation settings.
    static let preferenceSelectable: [MuscleGroup] = [
        .chest, .back, .shoulders, .biceps, .triceps,
        .quads, .hamstrings, .glutes, .calves, .abs
    ]
}

enum Equipment: String, Codable, CaseIterable, Identifiable, Hashable {
    case bodyweight, dumbbell, barbell, kettlebell, cable, machine
    case smithMachine, bench, squatRack, pullUpBar, resistanceBand
    case medicineBall, cardioMachine

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bodyweight: "Bodyweight"
        case .dumbbell: "Dumbbells"
        case .barbell: "Barbell"
        case .kettlebell: "Kettlebells"
        case .cable: "Cable Machine"
        case .machine: "Machines"
        case .smithMachine: "Smith Machine"
        case .bench: "Bench"
        case .squatRack: "Squat Rack"
        case .pullUpBar: "Pull-up Bar"
        case .resistanceBand: "Resistance Bands"
        case .medicineBall: "Medicine Ball"
        case .cardioMachine: "Cardio Equipment"
        }
    }
}

enum LoadTrackingMode: String, Codable, CaseIterable, Identifiable {
    /// Do not show (or persist) external load tracking.
    case none
    /// Default to bodyweight-style logging, but allow enabling external load later.
    case optional
    /// Commonly supports added external load (e.g. vest/backpack/plate).
    case supported
    /// External load is fundamental to tracking performance for this movement.
    case required

    var id: String { rawValue }
}

extension LoadTrackingMode {
    var shouldShowWeightFieldByDefault: Bool {
        switch self {
        case .supported, .required:
            true
        case .none, .optional:
            false
        }
    }

    var allowsExternalLoadPlanning: Bool {
        switch self {
        case .supported, .required:
            true
        case .none, .optional:
            false
        }
    }

    var disallowsExternalLoad: Bool {
        switch self {
        case .none, .optional:
            true
        case .supported, .required:
            false
        }
    }
}

enum MovementPattern: String, Codable, CaseIterable, Identifiable {
    case horizontalPush, verticalPush, horizontalPull, verticalPull
    case squat, hinge, lunge, carry, rotation, antiRotation
    case isolation, cardio, mobility

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .horizontalPush: "Horizontal Push"
        case .verticalPush: "Vertical Push"
        case .horizontalPull: "Horizontal Pull"
        case .verticalPull: "Vertical Pull"
        case .squat: "Squat"
        case .hinge: "Hinge"
        case .lunge: "Lunge"
        case .carry: "Carry"
        case .rotation: "Rotation"
        case .antiRotation: "Anti-Rotation"
        case .isolation: "Isolation"
        case .cardio: "Cardio"
        case .mobility: "Mobility"
        }
    }
}

enum ExerciseDifficulty: String, Codable, CaseIterable, Identifiable {
    case beginner, intermediate, advanced

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

enum ForceType: String, Codable { case push, pull, staticHold }
enum MechanicsType: String, Codable { case compound, isolation }

enum DemoAngle: String, Codable, CaseIterable {
    case front, side, fortyFive, closeUp
}

enum MediaLicense: String, Codable {
    case placeholder, muscleWiki, wger, original, bundled
}

enum WorkoutStatus: String, Codable {
    case planned, inProgress, completed, cancelled
}

enum WorkoutGenerationSource: String, Codable {
    case rulesEngine, aiAssisted, manual
}

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack, postWorkout

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum NutritionDataSource: String, Codable {
    case manual, mock, openFoodFacts, usda, healthKit
}

enum BodyPhotoPoseType: String, Codable, CaseIterable, Identifiable {
    case frontRelaxed, sideRelaxed, backRelaxed
    case frontFlexed, sideFlexed, backFlexed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .frontRelaxed: "Front Relaxed"
        case .sideRelaxed: "Side Relaxed"
        case .backRelaxed: "Back Relaxed"
        case .frontFlexed: "Front Flexed"
        case .sideFlexed: "Side Flexed"
        case .backFlexed: "Back Flexed"
        }
    }
}

enum CoachIntent: String, Codable {
    case explainWorkout, modifyWorkout, generateWorkout, analyzePlateau
    case proteinHelp, progressPhotoInsight, generalTrainingQuestion
    case motivation, unknown
}

enum SorenessLevel: String, Codable, CaseIterable, Identifiable {
    case none, mild, moderate, severe

    var id: String { rawValue }

    var recoveryPenalty: Double {
        switch self {
        case .none: 0
        case .mild: 5
        case .moderate: 15
        case .severe: 30
        }
    }

    /// Full penalty on recently trained muscles; half on others (systemic fatigue).
    func scopedRecoveryPenalty(trained: Bool) -> Double {
        switch self {
        case .none: 0
        case .severe: trained ? 30 : 15
        case .moderate: trained ? 15 : 7
        case .mild: trained ? 5 : 2
        }
    }
}

enum TimeOfDayPreference: String, Codable, CaseIterable, Identifiable {
    case morning, lunch, evening, flexible

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: "Sun"
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        }
    }
}

enum TrendDirection: String, Codable, CaseIterable, Identifiable {
    case increasing, stable, decreasing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .increasing: "Increasing"
        case .stable: "Stable"
        case .decreasing: "Decreasing"
        }
    }
}
