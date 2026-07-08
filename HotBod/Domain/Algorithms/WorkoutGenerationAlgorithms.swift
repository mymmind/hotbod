import Foundation

struct ExerciseSelectionResult {
    let exercises: [Exercise]
    let scores: [String: Double]
    let uncoveredMuscles: [MuscleGroup]
}

enum WorkoutGenerationAlgorithms {

    // MARK: - Scoring

    static func scoreExercises(
        _ exercises: [Exercise],
        targetMuscles: [MuscleGroup],
        experience: ExperienceLevel,
        stats: [UserExerciseStats],
        recoveryBias: Bool,
        favoriteIds: Set<String> = [],
        ignoreDifficultyPenalty: Bool = false
    ) -> [(Exercise, Double)] {
        exercises.map { exercise in
            let primaryMatches = exercise.primaryMuscles.filter { targetMuscles.contains($0) }.count
            let secondaryMatches = exercise.secondaryMuscles.filter { targetMuscles.contains($0) }.count
            let muscleScore = Double(primaryMatches) * GenerationConstants.Scoring.primaryMuscleWeight
            let secondaryScore = Double(secondaryMatches) * GenerationConstants.Scoring.secondaryMuscleWeight
            let statBonus = stats.contains { $0.exerciseId == exercise.id }
                ? GenerationConstants.Scoring.historyBonus
                : 0.0
            let favoriteBonus = favoriteIds.contains(exercise.id)
                ? GenerationConstants.Scoring.favoriteBonus
                : 0.0
            let difficultyPenalty = !ignoreDifficultyPenalty && exercise.difficulty == .advanced && experience == .beginner
                ? GenerationConstants.Scoring.beginnerAdvancedPenalty
                : 0.0
            var recoveryBonus = 0.0
            if recoveryBias {
                if exercise.resolvedMechanics == .isolation {
                    recoveryBonus += GenerationConstants.RecoverySession.isolationScoreBonus
                }
                switch exercise.difficulty {
                case .beginner: recoveryBonus += GenerationConstants.RecoverySession.beginnerDifficultyBonus
                case .intermediate: recoveryBonus += GenerationConstants.RecoverySession.intermediateDifficultyBonus
                case .advanced: recoveryBonus += GenerationConstants.RecoverySession.advancedDifficultyPenalty
                }
            }
            let score = muscleScore + secondaryScore + statBonus + favoriteBonus + difficultyPenalty + recoveryBonus
            return (exercise, score)
        }
    }

    static func rankScored(
        _ scored: [(Exercise, Double)],
        preferVariation: Bool,
        avoidIds: Set<String>,
        variationSeed: UInt64? = nil
    ) -> [(Exercise, Double)] {
        guard !avoidIds.isEmpty || preferVariation else {
            return scored.sorted { $0.1 > $1.1 }
        }

        var rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
        if let variationSeed {
            rng = SeededRandomNumberGenerator(seed: variationSeed)
        }

        let jittered = scored.map { exercise, score in
            (
                exercise,
                score + Double.random(
                    in: -GenerationConstants.Scoring.variationJitterMagnitude...GenerationConstants.Scoring.variationJitterMagnitude,
                    using: &rng
                )
            )
        }
        return jittered.sorted { $0.1 > $1.1 }
    }

    // MARK: - Selection

    static func selectExercises(
        ranked: [(Exercise, Double)],
        targetMuscles: [MuscleGroup],
        maxExercises: Int,
        minExercises: Int
    ) -> ExerciseSelectionResult {
        var selected: [(Exercise, Double)] = []
        var usedPatterns: Set<MovementPattern> = []
        var usedIds = Set<String>()

        for muscle in targetMuscles {
            guard selected.count < maxExercises else { break }
            if selected.contains(where: { $0.0.primaryMuscles.contains(muscle) }) { continue }
            guard let pick = ranked.first(where: { item in
                !usedIds.contains(item.0.id) &&
                item.0.primaryMuscles.contains(muscle) &&
                !(usedPatterns.contains(item.0.movementPattern) && selected.count >= 2)
            }) else { continue }
            selected.append(pick)
            usedIds.insert(pick.0.id)
            usedPatterns.insert(pick.0.movementPattern)
        }

        for item in ranked where selected.count < maxExercises {
            if usedIds.contains(item.0.id) { continue }
            if usedPatterns.contains(item.0.movementPattern) && selected.count >= 2 { continue }
            if item.0.primaryMuscles.contains(where: { targetMuscles.contains($0) }) {
                selected.append(item)
                usedIds.insert(item.0.id)
                usedPatterns.insert(item.0.movementPattern)
            }
        }

        if selected.count < minExercises {
            for item in ranked where !usedIds.contains(item.0.id) {
                guard item.0.primaryMuscles.contains(where: { targetMuscles.contains($0) }) else { continue }
                selected.append(item)
                usedIds.insert(item.0.id)
                if selected.count >= minExercises { break }
            }
        }

        let uncovered = targetMuscles.filter { muscle in
            !ranked.contains { $0.0.primaryMuscles.contains(muscle) }
        }
        let scores = Dictionary(uniqueKeysWithValues: selected.map { ($0.0.id, $0.1) })
        return ExerciseSelectionResult(
            exercises: orderForSession(selected),
            scores: scores,
            uncoveredMuscles: uncovered
        )
    }

    static func uncoveredMuscleWarning(_ muscles: [MuscleGroup]) -> String? {
        guard !muscles.isEmpty else { return nil }
        let names = muscles.map(\.displayName).joined(separator: ", ")
        return "No available exercises for target muscle(s): \(names)."
    }

    // MARK: - Ordering

    static func orderForSession(_ items: [(Exercise, Double)]) -> [Exercise] {
        items.sorted { lhs, rhs in
            let lhsCompound = lhs.0.resolvedMechanics == .compound
            let rhsCompound = rhs.0.resolvedMechanics == .compound
            if lhsCompound != rhsCompound { return lhsCompound && !rhsCompound }
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return patternPriority(lhs.0.movementPattern) > patternPriority(rhs.0.movementPattern)
        }
        .map(\.0)
    }

    static func patternPriority(_ pattern: MovementPattern) -> Int {
        switch pattern {
        case .squat, .hinge: 3
        case .horizontalPush, .horizontalPull, .verticalPush, .verticalPull: 2
        case .lunge: 1
        default: 0
        }
    }

    // MARK: - Prescription helpers

    static func restSeconds(goal: TrainingGoal, mechanics: MechanicsType) -> Int {
        switch goal {
        case .gainStrength:
            mechanics == .compound
                ? GenerationConstants.Session.strengthCompoundRestSeconds
                : GenerationConstants.Session.strengthIsolationRestSeconds
        case .loseFat:
            mechanics == .compound
                ? GenerationConstants.Session.fatLossCompoundRestSeconds
                : GenerationConstants.Session.fatLossIsolationRestSeconds
        default:
            mechanics == .compound
                ? GenerationConstants.Session.hypertrophyCompoundRestSeconds
                : GenerationConstants.Session.hypertrophyIsolationRestSeconds
        }
    }

    static func rpeTarget(
        sessionMode: SessionMode,
        experience: ExperienceLevel,
        isDeload: Bool,
        sleepScore: Double?
    ) -> Double {
        if sessionMode == .recovery { return GenerationConstants.RecoverySession.rpeTarget }
        if isDeload { return GenerationConstants.Session.deloadRpeTarget }
        if experience == .beginner { return GenerationConstants.Session.beginnerRpeTarget }
        var rpe = GenerationConstants.Session.standardRpeTarget
        if let sleepScore, sleepScore < GenerationConstants.Recovery.poorSleepScoreThreshold {
            rpe = min(rpe, GenerationConstants.Session.poorSleepMaxRpe)
        }
        return rpe
    }

    // MARK: - Duration

    static func workoutTitle(
        muscles: [MuscleGroup],
        goal: TrainingGoal,
        split: TrainingSplit,
        focus: SplitDayFocus?
    ) -> String {
        if muscles.isEmpty {
            #if DEBUG
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                assertionFailure("workoutTitle called with empty muscle targets")
            }
            #endif
            return "Workout"
        }
        let suffix = GenerationConstants.Titles.goalSuffix(for: goal)
        if let focus {
            return "\(focus.displayName) \(suffix)"
        }
        let lower = Set([MuscleGroup.quads, .hamstrings, .glutes, .calves])
        if muscles.allSatisfy({ lower.contains($0) }) { return "Lower Body \(suffix)" }
        if muscles.allSatisfy({ !lower.contains($0) }) { return "Upper Body \(suffix)" }
        switch split {
        case .pushPullLegs: return "Push Day \(suffix)"
        default: return "Full Body \(suffix)"
        }
    }

    static func estimateDurationMinutes(planned: [PlannedExercise]) -> Int {
        let totalSets = planned.reduce(0) { $0 + $1.targetSets.count }
        let workSeconds = totalSets * GenerationConstants.Session.durationWorkSecondsPerSet
        let restSeconds = planned.reduce(0) { partial, exercise in
            let sets = exercise.targetSets
            guard sets.count > 1 else { return partial }
            let betweenSets = (0..<(sets.count - 1)).reduce(0) { rest, index in
                rest + (sets[index].isWarmup
                    ? GenerationConstants.Warmup.restSeconds
                    : exercise.restSeconds)
            }
            return partial + betweenSets
        }
        let transitionSeconds = max(0, planned.count - 1) * GenerationConstants.Session.transitionSecondsPerExercise
        let totalSeconds = workSeconds + restSeconds + transitionSeconds + GenerationConstants.Session.durationWarmupSeconds
        return Int(ceil(Double(totalSeconds) / 60.0))
    }

    static func trimToDuration(
        planned: inout [PlannedExercise],
        scores: [String: Double],
        targetMuscles: [MuscleGroup],
        exerciseMap: [String: Exercise],
        targetDurationMinutes: Int
    ) {
        let maxDuration = Int(Double(targetDurationMinutes) * GenerationConstants.Session.durationOverTargetFraction)
        while estimateDurationMinutes(planned: planned) > maxDuration,
              planned.count > GenerationConstants.Session.minStandardExercises {
            guard let dropIndex = indexOfLowestScoredIsolationToDrop(
                planned: planned,
                scores: scores,
                targetMuscles: targetMuscles,
                exerciseMap: exerciseMap
            ) else { break }
            planned.remove(at: dropIndex)
            reindexOrder(&planned)
        }
    }

    private static func indexOfLowestScoredIsolationToDrop(
        planned: [PlannedExercise],
        scores: [String: Double],
        targetMuscles: [MuscleGroup],
        exerciseMap: [String: Exercise]
    ) -> Int? {
        let coverage = muscleCoverageCounts(
            planned: planned,
            exerciseMap: exerciseMap,
            targetMuscles: targetMuscles
        )
        let candidates: [(index: Int, score: Double)] = planned.enumerated().compactMap { index, plannedExercise in
            guard let exercise = exerciseMap[plannedExercise.exerciseId],
                  exercise.resolvedMechanics == .isolation else { return nil }
            let coveredMuscles = Set(exercise.primaryMuscles).intersection(Set(targetMuscles))
            let removable = coveredMuscles.allSatisfy { coverage[$0, default: 0] > 1 }
            guard removable else { return nil }
            return (index, scores[plannedExercise.exerciseId] ?? 0)
        }
        return candidates.min(by: { $0.score < $1.score })?.index
    }

    private static func muscleCoverageCounts(
        planned: [PlannedExercise],
        exerciseMap: [String: Exercise],
        targetMuscles: [MuscleGroup]
    ) -> [MuscleGroup: Int] {
        var counts: [MuscleGroup: Int] = [:]
        for plannedExercise in planned {
            guard let exercise = exerciseMap[plannedExercise.exerciseId] else { continue }
            for muscle in exercise.primaryMuscles where targetMuscles.contains(muscle) {
                counts[muscle, default: 0] += 1
            }
        }
        return counts
    }

    private static func reindexOrder(_ planned: inout [PlannedExercise]) {
        for index in planned.indices {
            planned[index].orderIndex = index
        }
    }
}

/// Deterministic RNG for variation jitter in tests.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x4D595DF4D0F33173 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var result = state
        result = (result ^ (result >> 30)) &* 0xBF58_476D_1CE4_E5B9
        result = (result ^ (result >> 27)) &* 0x94D0_49BB_1331_11EB
        return result ^ (result >> 31)
    }
}

enum WarmupSetPlanner {
    static func warmupSets(
        workingWeight: Double?,
        workingRepsMin: Int,
        rpeTarget: Double?
    ) -> [PlannedSet] {
        let warmupRPE = GenerationConstants.Warmup.rpeTarget
        guard let workingWeight, workingWeight > 0 else {
            let reps = max(
                GenerationConstants.Warmup.repsMin,
                Int(Double(workingRepsMin) * GenerationConstants.Warmup.bodyweightRepFraction)
            )
            return [
                PlannedSet(
                    targetRepsMin: reps,
                    targetRepsMax: reps,
                    rpeTarget: warmupRPE,
                    isWarmup: true
                )
            ]
        }

        let fractions = workingWeight >= GenerationConstants.Warmup.heavyWeightThresholdKg
            ? GenerationConstants.Warmup.heavyLoadFractions
            : GenerationConstants.Warmup.standardLoadFractions

        return fractions.map { fraction in
            let weight = max(
                GenerationConstants.Warmup.minWeightKg,
                roundToPlate(workingWeight * fraction)
            )
            return PlannedSet(
                targetRepsMin: GenerationConstants.Warmup.repsMin,
                targetRepsMax: GenerationConstants.Warmup.repsMax,
                targetWeightKg: weight,
                rpeTarget: rpeTarget ?? warmupRPE,
                isWarmup: true
            )
        }
    }

    private static func roundToPlate(_ kg: Double) -> Double {
        let increment = GenerationConstants.Warmup.plateIncrementKg
        return (kg / increment).rounded() * increment
    }
}
