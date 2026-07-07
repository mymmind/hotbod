import Foundation

enum RecoveryCalculator {
    static func defaultStates() -> [MuscleRecoveryState] {
        MuscleGroup.allCases.map {
            MuscleRecoveryState(muscleGroup: $0, recoveryPercentage: 85, lastTrainedAt: nil, accumulatedFatigue: 0)
        }
    }

    static func decayRecovery(
        states: [MuscleRecoveryState],
        experienceLevel: ExperienceLevel,
        hoursSinceReference: Double = 0
    ) -> [MuscleRecoveryState] {
        let rate = experienceLevel.recoveryRatePerHour
        return states.map { state in
            var updated = state
            let hours = hoursSinceReference > 0 ? hoursSinceReference :
                (state.lastTrainedAt.map { Date().timeIntervalSince($0) / 3600 } ?? 24)
            updated.recoveryPercentage = min(100, state.recoveryPercentage + hours * rate)
            updated.accumulatedFatigue = max(0, state.accumulatedFatigue - hours * 0.5)
            return updated
        }
    }

    static func applyWorkoutFatigue(
        states: [MuscleRecoveryState],
        exercises: [Exercise],
        completedSets: [(exercise: Exercise, sets: [CompletedSet])]
    ) -> [MuscleRecoveryState] {
        var map = Dictionary(uniqueKeysWithValues: states.map { ($0.muscleGroup, $0) })

        for item in completedSets {
            let workingSets = item.sets.filter { !$0.isWarmup }
            let intensityMultiplier = item.exercise.resolvedMechanics == .compound ? 1.2 : 0.8
            let contributions = muscleContributions(for: item.exercise)

            for (muscle, contribution) in contributions {
                var state = map[muscle] ?? MuscleRecoveryState(muscleGroup: muscle, recoveryPercentage: 85, lastTrainedAt: nil, accumulatedFatigue: 0)
                let fatigue = Double(workingSets.count) * intensityMultiplier * contribution * 8
                state.recoveryPercentage = max(0, state.recoveryPercentage - fatigue)
                state.accumulatedFatigue += fatigue
                state.lastTrainedAt = Date()
                map[muscle] = state
            }
        }
        return MuscleGroup.allCases.compactMap { map[$0] }
    }

    static func muscleContributions(for exercise: Exercise) -> [MuscleGroup: Double] {
        var contributions: [MuscleGroup: Double] = [:]
        for muscle in exercise.primaryMuscles {
            contributions[muscle, default: 0] += 1.0
        }
        for muscle in exercise.secondaryMuscles {
            contributions[muscle, default: 0] += 0.4
        }
        return contributions
    }

    static func applySoreness(states: [MuscleRecoveryState], level: SorenessLevel) -> [MuscleRecoveryState] {
        guard level != .none else { return states }
        return states.map { state in
            var updated = state
            updated.recoveryPercentage = max(0, state.recoveryPercentage - level.recoveryPenalty)
            return updated
        }
    }
}

enum ProteinGoalCalculator {
    static func suggestedGoal(bodyWeightKg: Double, goal: TrainingGoal, multiplier: Double? = nil) -> Double {
        let factor = multiplier ?? defaultMultiplier(for: goal)
        return (bodyWeightKg * factor).rounded()
    }

    static func defaultMultiplier(for goal: TrainingGoal) -> Double {
        switch goal {
        case .loseFat: 2.0
        case .buildMuscle, .gainStrength, .hybridAthlete: 1.8
        case .generalFitness, .athleticPerformance: 1.6
        }
    }

    static func rangeOptions(bodyWeightKg: Double) -> [(label: String, grams: Double)] {
        [
            ("1.6g/kg — normal", bodyWeightKg * 1.6),
            ("1.8g/kg — strong default", bodyWeightKg * 1.8),
            ("2.2g/kg — aggressive", bodyWeightKg * 2.2)
        ]
    }
}

enum VolumeTracker {
    private static let maxWeeks = 12

    static func recordSession(on stats: inout UserExerciseStats, date: Date = Date()) {
        let calendar = Calendar.current
        let currentWeekReps = stats.recentSets
            .filter { !$0.isWarmup && calendar.isDate($0.completedAt, equalTo: date, toGranularity: .weekOfYear) }
            .reduce(0) { $0 + $1.reps }

        let onlyCurrentWeekInRecent = stats.recentSets
            .filter { !$0.isWarmup && $0.reps > 0 }
            .allSatisfy { calendar.isDate($0.completedAt, equalTo: date, toGranularity: .weekOfYear) }

        if stats.weeklyVolume.isEmpty {
            stats.weeklyVolume = [currentWeekReps]
        } else if onlyCurrentWeekInRecent {
            if let lastWeekVolume = stats.weeklyVolume.last,
               currentWeekReps < lastWeekVolume,
               stats.recentSets.filter({ !$0.isWarmup }).count <= stats.weeklyMaxSets + 3 {
                stats.weeklyVolume.append(currentWeekReps)
            } else {
                stats.weeklyVolume[stats.weeklyVolume.count - 1] = currentWeekReps
            }
        } else {
            stats.weeklyVolume = weeklyVolumeHistory(from: stats.recentSets)
        }

        if stats.weeklyVolume.count > maxWeeks {
            stats.weeklyVolume.removeFirst(stats.weeklyVolume.count - maxWeeks)
        }

        stats.weeklyMaxSets = weeklySetCount(from: stats.recentSets, date: date)
        stats.volumeTrend = computeTrend(from: stats.weeklyVolume)
        updateConsecutiveHighVolumeWeeks(&stats)
    }

    static func weeklyVolumeHistory(from sets: [CompletedSet]) -> [Int] {
        let calendar = Calendar.current
        let working = sets.filter { !$0.isWarmup && $0.reps > 0 }.sorted { $0.completedAt < $1.completedAt }
        guard !working.isEmpty else { return [] }

        var weekVolumes: [Int] = []
        var currentWeekKey: Int?
        var currentVolume = 0

        for set in working {
            let week = calendar.component(.weekOfYear, from: set.completedAt)
            let year = calendar.component(.yearForWeekOfYear, from: set.completedAt)
            let key = year * 100 + week
            if currentWeekKey == key {
                currentVolume += set.reps
            } else {
                if currentWeekKey != nil {
                    weekVolumes.append(currentVolume)
                }
                currentWeekKey = key
                currentVolume = set.reps
            }
        }
        if currentWeekKey != nil {
            weekVolumes.append(currentVolume)
        }
        return Array(weekVolumes.suffix(maxWeeks))
    }

    static func weeklySetCount(from sets: [CompletedSet], date: Date) -> Int {
        let calendar = Calendar.current
        return sets.filter {
            !$0.isWarmup && calendar.isDate($0.completedAt, equalTo: date, toGranularity: .weekOfYear)
        }.count
    }

    static func computeTrend(from history: [Int]) -> TrendDirection {
        guard history.count >= 2 else { return .stable }
        let recent = Array(history.suffix(3))
        guard recent.count >= 2 else { return .stable }

        let changes = zip(recent.dropLast(), recent.dropFirst()).map { prev, next in
            Double(next) / Double(max(1, prev)) - 1.0
        }
        let avgChange = changes.reduce(0, +) / Double(changes.count)

        if avgChange > 0.10 { return .increasing }
        if avgChange < -0.10 { return .decreasing }
        return .stable
    }

    private static func updateConsecutiveHighVolumeWeeks(_ stats: inout UserExerciseStats) {
        guard stats.weeklyVolume.count >= 2 else {
            stats.consecutiveHighVolumeWeeks = 0
            return
        }
        let last = stats.weeklyVolume[stats.weeklyVolume.count - 1]
        let prev = stats.weeklyVolume[stats.weeklyVolume.count - 2]
        let increase = Double(last) / Double(max(1, prev)) - 1.0
        if increase > 0.15 {
            stats.consecutiveHighVolumeWeeks += 1
        } else {
            stats.consecutiveHighVolumeWeeks = 0
        }
    }
}

enum ProgressiveOverload {
    static func nextWeight(
        currentWeight: Double,
        completedAllSetsAtTopRange: Bool,
        missedMinimumReps: Bool
    ) -> Double {
        if completedAllSetsAtTopRange {
            return currentWeight + 2.5
        }
        if missedMinimumReps {
            return (currentWeight * 0.95 * 10).rounded() / 10
        }
        return currentWeight
    }

    static func nextWeight(
        current: Double,
        stats: UserExerciseStats,
        volumeCap: Int,
        setCountThisWeek: Int,
        bodyweight: Double
    ) -> Double {
        // If in deload week, reduce weight by 10%
        if stats.isInDeloadWeek {
            return current * 0.9
        }

        // If volume is decreasing significantly, maintain or reduce weight
        if stats.volumeTrend == .decreasing {
            return current
        }

        // If user hit volume cap this week, reduce intensity for next week
        if setCountThisWeek >= volumeCap {
            return current * 0.95
        }

        // If volume is increasing steadily, increment conservatively
        if stats.volumeTrend == .increasing {
            let increment = current < 20 ? current * 0.025 : 2.5
            return round((current + increment) * 2.0) / 2.0
        }

        // Stable volume: increment moderately
        let increment = current < 20 ? current * 0.05 : 5.0
        return round((current + increment) * 2.0) / 2.0
    }

    static func estimateOneRepMax(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }

    static func updateStats(
        existing: UserExerciseStats?,
        exerciseId: String,
        completedSets: [CompletedSet],
        plannedSets: [PlannedSet],
        bodyweightKg: Double = 80,
        experienceLevel: ExperienceLevel = .intermediate
    ) -> UserExerciseStats {
        let working = completedSets.filter { !$0.isWarmup && $0.reps > 0 }
        let last = working.last
        let lastWeight = last?.weightKg
        let lastReps = last?.reps
        let e1rm: Double? = {
            guard let w = last, let weight = w.weightKg else { return nil }
            return estimateOneRepMax(weight: weight, reps: w.reps)
        }()
        let bestVolume = working.map { ($0.weightKg ?? 0) * Double($0.reps) }.max()

        let workingPlanned = plannedSets.filter { !$0.isWarmup }
        let hitTop = working.count == workingPlanned.count && zip(working, workingPlanned).allSatisfy { set, planned in
            set.reps >= planned.targetRepsMax
        }
        let missedMin = zip(working, workingPlanned).contains { set, planned in
            set.reps < planned.targetRepsMin
        }

        var recentSets = (existing?.recentSets ?? []) + working
        recentSets = Array(recentSets.suffix(12))

        var stats = UserExerciseStats(
            exerciseId: exerciseId,
            lastWeightKg: lastWeight,
            lastReps: lastReps,
            suggestedNextWeightKg: nil,
            estimatedOneRepMax: e1rm,
            bestVolumeSet: bestVolume,
            recentSets: recentSets,
            preferredRepRangeMin: workingPlanned.first?.targetRepsMin ?? existing?.preferredRepRangeMin ?? 8,
            preferredRepRangeMax: workingPlanned.first?.targetRepsMax ?? existing?.preferredRepRangeMax ?? 12
        )

        if let existing {
            stats.weeklyVolume = existing.weeklyVolume
            stats.weeklyMaxSets = existing.weeklyMaxSets
            stats.volumeTrend = existing.volumeTrend
            stats.isInDeloadWeek = existing.isInDeloadWeek
            stats.lastDeloadDate = existing.lastDeloadDate
            stats.consecutiveHighVolumeWeeks = existing.consecutiveHighVolumeWeeks
        }

        VolumeTracker.recordSession(on: &stats)
        DeloadDetector.updateDeloadState(stats: &stats)

        if let lastWeight = lastWeight {
            let volumeCap = VolumeCapCalculator.adjustedWeeklySetCap(
                experience: experienceLevel,
                soreness: .none
            )
            if hitTop || missedMin {
                stats.suggestedNextWeightKg = nextWeight(
                    currentWeight: lastWeight,
                    completedAllSetsAtTopRange: hitTop,
                    missedMinimumReps: missedMin
                )
            } else {
                stats.suggestedNextWeightKg = nextWeight(
                    current: lastWeight,
                    stats: stats,
                    volumeCap: volumeCap,
                    setCountThisWeek: stats.weeklyMaxSets,
                    bodyweight: bodyweightKg
                )
            }
        }

        return stats
    }

    static func suggestedStartWeight(
        for exercise: Exercise,
        bodyweight: Double,
        experience: ExperienceLevel
    ) -> Double {
        let baseWeight: Double
        switch exercise.movementPattern {
        case .horizontalPush, .verticalPush:
            baseWeight = exercise.equipment.contains(.bodyweight) ? bodyweight * 0.4 : bodyweight * 0.25
        case .horizontalPull, .verticalPull:
            baseWeight = exercise.equipment.contains(.bodyweight) ? bodyweight * 0.35 : bodyweight * 0.2
        case .squat, .hinge:
            baseWeight = bodyweight * 0.75
        case .lunge, .carry:
            baseWeight = bodyweight * 0.25
        default:
            baseWeight = bodyweight * 0.2
        }

        let experienceFactor: Double = switch experience {
        case .beginner: 0.7
        case .intermediate: 1.0
        case .advanced: 1.3
        }

        return round(baseWeight * experienceFactor * 2.0) / 2.0
    }
}

enum IntensityCalculator {
    /// Estimates RPE (Rating of Perceived Exertion) based on rep range.
    /// Lower reps = higher intensity, higher reps = lower intensity.
    static func estimateRPE(reps: Int, rpeTarget: Double = 8.0) -> Double {
        switch reps {
        case 1...3: return 9.0
        case 4...6: return 8.5
        case 7...9: return 8.0
        case 10...12: return 7.5
        case 13...15: return 7.0
        default: return 6.5
        }
    }

    /// Calculates relative volume intensity (0.0-1.0) based on sets and target rep max.
    /// Higher sets + lower reps = higher intensity.
    static func volumeIntensity(setCount: Int, targetRepsMax: Int) -> Double {
        let setFactor = Double(setCount) / 5.0
        let repFactor = 1.0 - (Double(targetRepsMax) / 30.0)
        return min(1.0, (setFactor + repFactor) / 2.0)
    }

    /// Calculates estimated workout intensity (0.0-1.0) based on exercises.
    static func workoutIntensity(
        exercises: [PlannedExercise],
        exerciseMap: [String: Exercise]
    ) -> Double {
        guard !exercises.isEmpty else { return 0.5 }

        var totalIntensity = 0.0
        var compoundCount = 0

        for planned in exercises {
            let exercise = exerciseMap[planned.exerciseId]
            let isCompound = (exercise?.resolvedMechanics == .compound)
            let setCount = planned.targetSets.filter { !$0.isWarmup }.count
            let avgReps = (planned.targetSets.first { !$0.isWarmup }?.targetRepsMax ?? 12)

            let baseIntensity = volumeIntensity(setCount: setCount, targetRepsMax: avgReps)
            let compoundBoost = isCompound ? 1.2 : 1.0
            totalIntensity += baseIntensity * compoundBoost

            if isCompound { compoundCount += 1 }
        }

        return min(1.0, totalIntensity / Double(exercises.count))
    }

    /// Fatigue-adjusted intensity: reduces intensity recommendation based on recovery.
    static func fatigueAdjustedIntensity(baseIntensity: Double, recoveryPercent: Double) -> Double {
        if recoveryPercent >= 70 {
            return baseIntensity
        } else if recoveryPercent >= 50 {
            return baseIntensity * 0.85
        } else if recoveryPercent >= 30 {
            return baseIntensity * 0.70
        } else {
            return baseIntensity * 0.50
        }
    }
}

enum VolumeCalculator {
    /// Calculates total working sets in a workout (excludes warm-ups).
    static func totalSets(exercises: [PlannedExercise]) -> Int {
        exercises.reduce(0) { $0 + $1.targetSets.filter { !$0.isWarmup }.count }
    }

    /// Estimates weekly sets from recent workouts.
    static func weeklyVolumeEstimate(recentWorkouts: [WorkoutSessionSummary], days: Int = 7) -> Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let thisWeek = recentWorkouts.filter { $0.completedAt >= weekAgo }
        return thisWeek.reduce(0) { $0 + $1.totalSets }
    }

    /// Volume reduction factor based on soreness level (single source: GenerationConstants).
    static func sorenessVolumeFactor(soreness: SorenessLevel) -> Double {
        GenerationConstants.Volume.sorenessReductionFactor(soreness)
    }

    /// Recommended volume cap based on soreness and recovery.
    static func volumeCap(soreness: SorenessLevel, avgRecovery: Double) -> Int? {
        let baseCap = 30
        let factor = sorenessVolumeFactor(soreness: soreness)

        if avgRecovery < 30 && soreness.rawValue != "none" {
            return Int(Double(baseCap) * factor * 0.8)
        } else if avgRecovery < 50 {
            return Int(Double(baseCap) * factor * 0.9)
        }
        return nil
    }
}

enum WorkoutSessionCalculator {
    /// Moderate strength-training MET (Ainsworth compendium).
    private static let strengthTrainingMET = 5.0

    static func estimatedCaloriesBurned(elapsedSeconds: Int, bodyWeightKg: Double) -> Int {
        guard elapsedSeconds > 0, bodyWeightKg > 0 else { return 0 }
        let hours = Double(elapsedSeconds) / 3600.0
        return Int((strengthTrainingMET * bodyWeightKg * hours).rounded())
    }

    static func totalPlannedSets(exercises: [WorkoutExercise]) -> Int {
        exercises.reduce(0) { $0 + $1.plannedSets.count }
    }

    static func exerciseProgress(currentIndex: Int, exerciseCount: Int) -> Double {
        guard exerciseCount > 0 else { return 0 }
        return Double(currentIndex + 1) / Double(exerciseCount)
    }

    /// First exercise that still has sets to log; falls back to last non-skipped exercise.
    static func currentExerciseIndex(for session: WorkoutSession) -> Int {
        if let idx = session.exercises.firstIndex(where: {
            !$0.wasSkipped && $0.completedSets.count < $0.plannedSets.count
        }) {
            return idx
        }
        if let last = session.exercises.lastIndex(where: { !$0.wasSkipped }) {
            return last
        }
        return max(0, session.exercises.count - 1)
    }

    static func completedVolumeKg(session: WorkoutSession) -> Double {
        session.exercises.flatMap(\.completedSets).reduce(0) { partial, set in
            partial + (set.weightKg ?? 0) * Double(set.reps)
        }
    }

    static func completedSetCount(session: WorkoutSession) -> Int {
        session.exercises.flatMap(\.completedSets).count
    }

    static func formattedElapsed(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}

