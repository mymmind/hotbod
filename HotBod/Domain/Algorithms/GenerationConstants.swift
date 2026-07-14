import Foundation

/// Shared thresholds and weights for workout generation and validation.
enum GenerationConstants {

    enum Volume {
        static func baseWeeklySetCap(experience: ExperienceLevel) -> Int {
            switch experience {
            case .beginner: 70
            case .intermediate: 100
            case .advanced: 130
            }
        }

        static func sorenessReductionFactor(_ soreness: SorenessLevel) -> Double {
            switch soreness {
            case .none: 1.0
            case .mild: 0.9
            case .moderate: 0.8
            case .severe: 0.6
            }
        }

        static func adjustedWeeklySetCap(experience: ExperienceLevel, soreness: SorenessLevel) -> Int {
            Int(Double(baseWeeklySetCap(experience: experience)) * sorenessReductionFactor(soreness))
        }

        /// Soft warning when projected weekly sets exceed this fraction of the adjusted cap.
        static let warningCapFraction = 0.85

        static func warningThreshold(experience: ExperienceLevel, soreness: SorenessLevel) -> Int {
            Int(Double(adjustedWeeklySetCap(experience: experience, soreness: soreness)) * warningCapFraction)
        }
    }

    enum Recovery {
        /// Muscles absent from the recovery map are treated as fully recovered (never trained).
        static let defaultMuscleRecovery: Double = 100

        static func recovery(for muscle: MuscleGroup, in map: [MuscleGroup: Double]) -> Double {
            map[muscle] ?? defaultMuscleRecovery
        }

        static func minimumRecovery(in map: [MuscleGroup: Double]) -> Double {
            MuscleGroup.allCases.map { recovery(for: $0, in: map) }.min() ?? defaultMuscleRecovery
        }

        static func averageRecovery(in map: [MuscleGroup: Double]) -> Double {
            let values = MuscleGroup.allCases.map { recovery(for: $0, in: map) }
            return values.reduce(0, +) / Double(values.count)
        }

        static let splitMuscleMinRecovery: Double = 40
        static let readyMuscleMinRecovery: Double = 50
        static let lowRecoveryWarningThreshold: Double = 30
        static let criticalFatigueThreshold: Double = 15
        static let recoverySessionAvgThreshold: Double = 25
        static let severeSorenessRecoveryPenalty: Double = 20
        static let moderateSorenessRecoveryPenalty: Double = 10
        static let poorSleepRecoveryPenalty: Double = 10
        static let suboptimalSleepRecoveryPenalty: Double = 5
        static let poorSleepScoreThreshold: Double = 50
        static let suboptimalSleepScoreThreshold: Double = 70
    }

    enum Targeting {
        static let preferredMuscleRecoveryBonus: Double = 15
        static let minCandidatesAfterAvoidance = 2
        static let minCandidatesBeforeRelaxation = 6
        static let avoidedExercisesRelaxationMessage =
            "Including avoided exercises — not enough alternatives."
        static let difficultyRelaxationMessage =
            "Including advanced exercises — not enough alternatives for your experience level."
        static let avoidedMusclesOverrideMessage =
            "Avoided muscles overridden — insufficient recovered muscles for this session."
    }

    enum RecoverySession {
        static let weightMultiplier = 0.7
        static let rpeTarget = 6.0
        static let minExercises = 3
        static let maxExercises = 4
        static let targetMuscleCount = 3
        static let isolationScoreBonus = 5.0
        static let beginnerDifficultyBonus = 2.0
        static let intermediateDifficultyBonus = 1.0
        static let advancedDifficultyPenalty = -2.0
    }

    enum Scoring {
        static let primaryMuscleWeight = 10.0
        static let secondaryMuscleWeight = 4.0
        static let historyBonus = 2.0
        static let beginnerAdvancedPenalty = -5.0
        static let favoriteBonus = 3.0
        static let lessPreferredPenalty = -4.0
        static let variationJitterMagnitude = 1.5
    }

    enum Progression {
        static let easyRPEThreshold = 7.0
        static let hardRPEThreshold = 9.0
        static let veryHardRPEThreshold = 9.5
        static let easyProgressionMultiplier = 1.5
        static let moderateProgressionMultiplier = 0.5
        static let highRPEDeloadSetCount = 3
    }

    enum MaxEffort {
        static let sessionsBetweenCalibration = 5
        static let workingWeightFraction = 0.80
    }

    enum Grouping {
        static let supersetSize = 2
        static let circuitSize = 3
        static let transitionRestSeconds = 15
        static let defaultGroupRestSeconds = 90
    }

    enum Session {
        static let minStandardExercises = 4
        static let maxExercisesCap = 8
        static let minutesPerExerciseDivisor = 8
        static let standardRpeTarget = 8.0
        static let beginnerRpeTarget = 7.0
        static let deloadRpeTarget = 6.0
        static let poorSleepMaxRpe = 7.0
        static let strengthCompoundRestSeconds = 180
        static let strengthIsolationRestSeconds = 90
        static let hypertrophyCompoundRestSeconds = 120
        static let hypertrophyIsolationRestSeconds = 75
        static let fatLossCompoundRestSeconds = 90
        static let fatLossIsolationRestSeconds = 60
        static let compoundRestSeconds = 120
        static let isolationRestSeconds = 90
        static let deloadSetMultiplier = 0.6
        static let durationWorkSecondsPerSet = 45
        static let transitionSecondsPerExercise = 120
        static let durationWarmupSeconds = 300
        static let durationOverTargetFraction = 1.10
        static let durationWorkMinutesPerSet = 2
        static let durationWarmupMinutes = 5
        static let beginnerStartWeightClampMultiplier = 1.5
        static let beginnerBaseSets = 2
        static let defaultBaseSets = 3
        static let bigPatternExtraSets = 1
        static let bigMovementPatterns: Set<MovementPattern> = [
            .squat, .hinge, .horizontalPush, .horizontalPull
        ]
        static let flatBeginnerBarbellWeightKg = 40.0
        static let flatIntermediateBarbellWeightKg = 60.0
        static let flatAdvancedBarbellWeightKg = 80.0
        static let flatBeginnerDumbbellWeightKg = 12.0
        static let flatIntermediateDumbbellWeightKg = 20.0
        static let flatAdvancedDumbbellWeightKg = 28.0
        static let defaultBodyweightKgFallback = 80.0
    }

    enum Warmup {
        static let repsMin = 5
        static let repsMax = 8
        static let rpeTarget = 5.0
        static let restSeconds = 45
        static let minWeightKg = 2.5
        static let heavyWeightThresholdKg = 80.0
        static let standardLoadFractions: [Double] = [0.5, 0.75]
        static let heavyLoadFractions: [Double] = [0.4, 0.6, 0.8]
        static let bodyweightRepFraction = 0.6
        static let plateIncrementKg = 2.5
    }

    enum Cooldown {
        static let repsMin = 10
        static let repsMax = 15
        static let rpeTarget = 4.0
        static let restSeconds = 30
    }

    enum CardioBlock {
        static let repsMin = 5
        static let repsMax = 10
        static let rpeTarget = 6.0
        static let restSeconds = 60
    }

    enum Prescription {
        static func repRange(for goal: TrainingGoal, experience: ExperienceLevel) -> (min: Int, max: Int) {
            switch goal {
            case .gainStrength: (4, 6)
            case .loseFat: (12, 15)
            default: experience == .beginner ? (10, 12) : (8, 10)
            }
        }

        /// Uses historical rep ranges only when they were learned under the current goal.
        static func effectiveRepRange(
            stats: UserExerciseStats?,
            goal: TrainingGoal,
            experience: ExperienceLevel
        ) -> (min: Int, max: Int) {
            let goalRange = repRange(for: goal, experience: experience)
            guard let stats, stats.goalAtLastUpdate == goal else {
                return goalRange
            }
            return (stats.preferredRepRangeMin, stats.preferredRepRangeMax)
        }

        static func setCount(experience: ExperienceLevel, pattern: MovementPattern) -> Int {
            let base = experience == .beginner
                ? GenerationConstants.Session.beginnerBaseSets
                : GenerationConstants.Session.defaultBaseSets
            return GenerationConstants.Session.bigMovementPatterns.contains(pattern)
                ? base + GenerationConstants.Session.bigPatternExtraSets
                : base
        }
    }

    enum Titles {
        static func goalSuffix(for goal: TrainingGoal) -> String {
            switch goal {
            case .gainStrength: "Strength"
            case .loseFat: "Conditioning"
            default: "Hypertrophy"
            }
        }
    }

    enum Validation {
        static let highIntensityThreshold = 0.75
        static let durationOverTargetMinutes = 20
        static let moderateSorenessVolumeReduction = 0.8
        static let lowRecoveryAdjustedIntensityFraction = 0.6
        static let minRepCount = 1
        static let maxRepCount = 30
        static let maxPlannedWeightKg = 400.0
        static let minRestSeconds = 15
        static let maxRestSeconds = 600
        static let minSetsPerExercise = 1
        static let maxSetsPerExercise = 8
        static let weightJumpWarningMultiplier = 1.5
    }

    enum Time {
        static let rollingWindowSeconds: TimeInterval = 7 * 24 * 60 * 60
        static let maxDecayHours: Double = 14 * 24

        static func rollingWindowStart(endingAt now: Date) -> Date {
            now.addingTimeInterval(-rollingWindowSeconds)
        }

        static func previousRollingWindowStart(endingAt now: Date) -> Date {
            now.addingTimeInterval(-2 * rollingWindowSeconds)
        }

        static func isInRollingWindow(_ date: Date, endingAt now: Date) -> Bool {
            date >= rollingWindowStart(endingAt: now) && date <= now
        }

        static func isInPreviousRollingWindow(_ date: Date, endingAt now: Date) -> Bool {
            let windowEnd = rollingWindowStart(endingAt: now)
            let windowStart = previousRollingWindowStart(endingAt: now)
            return date >= windowStart && date < windowEnd
        }
    }

    enum Deload {
        static let minPreviousWindowSets = 10
        static let minCurrentWindowSetsForDrop = 5
        static let volumeDropThreshold = 0.3
        static let reEntryWeightMultiplier = 0.9
        static let reEntryRPETarget = 7.0
    }

    enum Weight {
        static let dumbbellIncrementKg = 2.0
        static let barbellIncrementKg = 2.5

        // TODO: user-configurable micro-plate increments
        static func roundToAvailable(
            _ kg: Double,
            equipment: [Equipment],
            ceilings: [Equipment: Double] = [:]
        ) -> Double {
            let rounded: Double
            if equipment.contains(.dumbbell) {
                rounded = (kg / dumbbellIncrementKg).rounded() * dumbbellIncrementKg
            } else if equipment.contains(.barbell) {
                rounded = (kg / barbellIncrementKg).rounded() * barbellIncrementKg
            } else {
                rounded = (kg / barbellIncrementKg).rounded() * barbellIncrementKg
            }
            return applyCeilings(to: rounded, equipment: equipment, ceilings: ceilings)
        }

        static func applyCeilings(
            to kg: Double,
            equipment: [Equipment],
            ceilings: [Equipment: Double]
        ) -> Double {
            guard !ceilings.isEmpty else { return kg }
            var capped = kg
            for piece in equipment {
                if let ceiling = ceilings[piece] {
                    capped = min(capped, ceiling)
                }
            }
            return capped
        }
    }

    /// Movement-pattern blocks for reported body limitations.
    static let injuryRiskyPatterns: [BodyLimitation: [MovementPattern]] = [
        .shoulder: [.verticalPush, .horizontalPush],
        .lowerBack: [.hinge, .squat],
        .knee: [.squat, .lunge],
        .elbow: [.verticalPush, .horizontalPush],
        .wrist: [.verticalPush, .horizontalPush],
        .hip: [.hinge, .squat, .lunge],
        .ankle: [.squat, .lunge],
        .neck: [.verticalPush],
    ]

    static func violatesInjuries(_ exercise: Exercise, injuries: [BodyLimitation]) -> Bool {
        guard !injuries.contains(.none) else { return false }
        return injuries.contains { injury in
            let blocksPattern = injuryRiskyPatterns[injury]?.contains(exercise.movementPattern) == true
            let blocksContraindications = contraindicationTerms[injury]?.contains { term in
                let normalizedContraindications = exercise.contraindications
                    .joined(separator: " ")
                    .lowercased()
                return normalizedContraindications.contains(term)
            } == true
            return blocksPattern || blocksContraindications
        }
    }

    private static let contraindicationTerms: [BodyLimitation: [String]] = [
        .shoulder: ["shoulder", "impingement", "rotator cuff"],
        .lowerBack: ["lower back", "lumbar", "spine"],
        .knee: ["knee", "patella", "acl"],
        .elbow: ["elbow", "tendonitis", "tennis elbow"],
        .wrist: ["wrist", "carpal"],
        .hip: ["hip", "hip flexor", "si joint"],
        .ankle: ["ankle", "achilles"],
        .neck: ["neck", "cervical"],
        .none: []
    ]
}

enum EquipmentFilter {
    static func effectiveEquipment(_ available: [Equipment]) -> Set<Equipment> {
        Set(available).union([.bodyweight])
    }

    static func isExerciseAvailable(_ exercise: Exercise, availableEquipment: [Equipment]) -> Bool {
        !exercise.equipment.isEmpty &&
        exercise.equipment.allSatisfy { effectiveEquipment(availableEquipment).contains($0) }
    }
}

enum ExerciseIdResolver {
    static func normalize(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func canonicalId(
        _ raw: String,
        catalog: Set<String>,
        aliasIndex: [String: String]
    ) -> String? {
        let normalized = normalize(raw)
        if catalog.contains(normalized) { return normalized }
        return aliasIndex[normalized]
    }
}

extension Exercise {
    var resolvedMechanics: MechanicsType {
        if let mechanics { return mechanics }
        return movementPattern.inferredMechanics
    }
}

extension MovementPattern {
    var inferredMechanics: MechanicsType {
        switch self {
        case .squat, .hinge, .lunge, .horizontalPush, .horizontalPull,
             .verticalPush, .verticalPull, .carry:
            return .compound
        case .rotation, .antiRotation, .isolation, .cardio, .mobility:
            return .isolation
        }
    }
}
