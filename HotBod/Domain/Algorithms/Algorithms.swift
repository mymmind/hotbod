import Foundation

enum RecoveryCalculator {
    static func defaultStates() -> [MuscleRecoveryState] {
        MuscleGroup.allCases.map {
            MuscleRecoveryState(
                muscleGroup: $0,
                recoveryPercentage: GenerationConstants.Recovery.defaultMuscleRecovery,
                lastTrainedAt: nil,
                accumulatedFatigue: 0
            )
        }
    }

    /// Keeps the lowest recovery per muscle, clamps to 0–100%, and backfills missing groups at 100%.
    static func normalizeStates(_ states: [MuscleRecoveryState]) -> [MuscleRecoveryState] {
        var byMuscle: [MuscleGroup: MuscleRecoveryState] = [:]
        for state in states {
            var normalized = state
            normalized.recoveryPercentage = min(100, max(0, state.recoveryPercentage))
            if let existing = byMuscle[normalized.muscleGroup] {
                if normalized.recoveryPercentage < existing.recoveryPercentage {
                    byMuscle[normalized.muscleGroup] = normalized
                }
            } else {
                byMuscle[normalized.muscleGroup] = normalized
            }
        }

        for muscle in MuscleGroup.allCases where byMuscle[muscle] == nil {
            byMuscle[muscle] = MuscleRecoveryState(
                muscleGroup: muscle,
                recoveryPercentage: GenerationConstants.Recovery.defaultMuscleRecovery,
                lastTrainedAt: nil,
                accumulatedFatigue: 0
            )
        }

        return MuscleGroup.allCases.compactMap { byMuscle[$0] }
    }

    static func recoveryMap(from states: [MuscleRecoveryState]) -> [MuscleGroup: Double] {
        Dictionary(
            normalizeStates(states).map { ($0.muscleGroup, $0.recoveryPercentage) },
            uniquingKeysWith: min
        )
    }

    static func decayRecovery(
        states: [MuscleRecoveryState],
        experienceLevel: ExperienceLevel,
        lastDecayAppliedAt: Date? = nil,
        now: Date = Date()
    ) -> (states: [MuscleRecoveryState], lastDecayAppliedAt: Date) {
        let rate = experienceLevel.recoveryRatePerHour
        let globalHours: Double

        if let lastDecay = lastDecayAppliedAt {
            let rawHours = now.timeIntervalSince(lastDecay) / 3600
            globalHours = min(max(0, rawHours), GenerationConstants.Time.maxDecayHours)
        } else {
            globalHours = 0
        }

        let updated = states.map { state -> MuscleRecoveryState in
            var updatedState = state
            let hours: Double
            if lastDecayAppliedAt == nil, let lastTrained = state.lastTrainedAt {
                let rawHours = now.timeIntervalSince(lastTrained) / 3600
                hours = min(max(0, rawHours), GenerationConstants.Time.maxDecayHours)
            } else {
                hours = globalHours
            }
            updatedState.recoveryPercentage = min(100, state.recoveryPercentage + hours * rate)
            updatedState.accumulatedFatigue = max(0, state.accumulatedFatigue - hours * 0.5)
            return updatedState
        }

        return (updated, now)
    }

    static func applyWorkoutFatigue(
        states: [MuscleRecoveryState],
        exercises: [Exercise],
        completedSets: [(exercise: Exercise, sets: [CompletedSet])]
    ) -> [MuscleRecoveryState] {
        var map = Dictionary(
            normalizeStates(states).map { ($0.muscleGroup, $0) },
            uniquingKeysWith: { left, _ in left }
        )

        for item in completedSets {
            let workingSets = item.sets.filter { !$0.isWarmup }
            let intensityMultiplier = item.exercise.resolvedMechanics == .compound ? 1.2 : 0.8
            let contributions = muscleContributions(for: item.exercise)

            for (muscle, contribution) in contributions {
                var state = map[muscle] ?? MuscleRecoveryState(
                    muscleGroup: muscle,
                    recoveryPercentage: GenerationConstants.Recovery.defaultMuscleRecovery,
                    lastTrainedAt: nil,
                    accumulatedFatigue: 0
                )
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

    static func applySoreness(
        states: [MuscleRecoveryState],
        level: SorenessLevel,
        recentlyTrainedMuscles: Set<MuscleGroup> = []
    ) -> [MuscleRecoveryState] {
        guard level != .none else { return states }
        return states.map { state in
            var updated = state
            let trained = recentlyTrainedMuscles.contains(state.muscleGroup)
            let penalty = level.scopedRecoveryPenalty(trained: trained)
            updated.recoveryPercentage = max(0, state.recoveryPercentage - penalty)
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
        stats.weeklyVolume = weeklyVolumeHistory(from: stats.recentSets, endingAt: date)
        if stats.weeklyVolume.count > maxWeeks {
            stats.weeklyVolume.removeFirst(stats.weeklyVolume.count - maxWeeks)
        }

        stats.weeklyMaxSets = rollingSetCount(from: stats.recentSets, endingAt: date)
        stats.volumeTrend = computeTrend(from: stats.weeklyVolume)
        updateConsecutiveHighVolumeWeeks(&stats)
    }

    /// Rolling 7×24h rep totals for consecutive windows ending at `now`, oldest first.
    static func weeklyVolumeHistory(from sets: [CompletedSet], endingAt now: Date = Date()) -> [Int] {
        let working = sets.filter { !$0.isWarmup && $0.reps > 0 }
        guard !working.isEmpty else { return [] }

        var volumes: [Int] = []
        var windowEnd = now
        for _ in 0..<maxWeeks {
            let windowStart = GenerationConstants.Time.rollingWindowStart(endingAt: windowEnd)
            let reps = working
                .filter { $0.completedAt >= windowStart && $0.completedAt <= windowEnd }
                .reduce(0) { $0 + $1.reps }
            if reps > 0 {
                volumes.insert(reps, at: 0)
            } else if !volumes.isEmpty {
                break
            }
            if windowStart <= Date(timeIntervalSince1970: 0) { break }
            windowEnd = windowStart.addingTimeInterval(-1)
        }
        return volumes
    }

    static func rollingSetCount(from sets: [CompletedSet], endingAt now: Date) -> Int {
        sets.filter {
            !$0.isWarmup && GenerationConstants.Time.isInRollingWindow($0.completedAt, endingAt: now)
        }.count
    }

    static func rollingSetCountInPreviousWindow(from sets: [CompletedSet], endingAt now: Date) -> Int {
        sets.filter {
            !$0.isWarmup && GenerationConstants.Time.isInPreviousRollingWindow($0.completedAt, endingAt: now)
        }.count
    }

    static func rollingRepCount(from sets: [CompletedSet], endingAt now: Date) -> Int {
        sets.filter {
            !$0.isWarmup && $0.reps > 0 && GenerationConstants.Time.isInRollingWindow($0.completedAt, endingAt: now)
        }.reduce(0) { $0 + $1.reps }
    }

    static func rollingRepCountInPreviousWindow(from sets: [CompletedSet], endingAt now: Date) -> Int {
        sets.filter {
            !$0.isWarmup && $0.reps > 0 && GenerationConstants.Time.isInPreviousRollingWindow($0.completedAt, endingAt: now)
        }.reduce(0) { $0 + $1.reps }
    }

    static func weeklySetCount(from sets: [CompletedSet], endingAt now: Date) -> Int {
        rollingSetCount(from: sets, endingAt: now)
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
    static func averageLoggedRPE(from sets: [CompletedSet]) -> Double? {
        EffortFeedbackMapping.averageEffectiveRPE(from: sets)
    }

    static func rpeProgressionMultiplier(averageLoggedRPE: Double?) -> Double {
        guard let rpe = averageLoggedRPE else { return 1.0 }
        if rpe <= GenerationConstants.Progression.easyRPEThreshold {
            return GenerationConstants.Progression.easyProgressionMultiplier
        }
        if rpe <= 8.0 { return 1.0 }
        if rpe <= GenerationConstants.Progression.hardRPEThreshold {
            return GenerationConstants.Progression.moderateProgressionMultiplier
        }
        return 0.0
    }

    static func nextWeight(
        currentWeight: Double,
        completedAllSetsAtTopRange: Bool,
        missedMinimumReps: Bool,
        averageLoggedRPE: Double? = nil,
        equipment: [Equipment] = []
    ) -> Double {
        let raw: Double
        if completedAllSetsAtTopRange {
            let increment = GenerationConstants.Weight.barbellIncrementKg
                * rpeProgressionMultiplier(averageLoggedRPE: averageLoggedRPE)
            raw = currentWeight + increment
        } else if missedMinimumReps {
            if let rpe = averageLoggedRPE, rpe >= GenerationConstants.Progression.veryHardRPEThreshold {
                raw = (currentWeight * 0.90 * 10).rounded() / 10
            } else {
                raw = (currentWeight * 0.95 * 10).rounded() / 10
            }
        } else {
            return GenerationConstants.Weight.roundToAvailable(currentWeight, equipment: equipment)
        }
        return GenerationConstants.Weight.roundToAvailable(raw, equipment: equipment)
    }

    static func nextWeight(
        current: Double,
        stats: UserExerciseStats,
        volumeCap: Int,
        setCountThisWeek: Int,
        bodyweight: Double,
        equipment: [Equipment] = []
    ) -> Double {
        let averageLoggedRPE = averageLoggedRPE(from: stats.recentSets)
        let rpeMultiplier = rpeProgressionMultiplier(averageLoggedRPE: averageLoggedRPE)
        let raw: Double
        // If in deload week, reduce weight by 10%
        if stats.isInDeloadWeek {
            raw = current * 0.9
        } else if stats.returningFromBreak {
            raw = current * GenerationConstants.Deload.reEntryWeightMultiplier
        } else if stats.volumeTrend == .decreasing {
            raw = current
        } else if setCountThisWeek >= volumeCap {
            raw = current * 0.95
        } else if stats.volumeTrend == .increasing {
            let increment = current < 20 ? current * 0.025 : GenerationConstants.Weight.barbellIncrementKg
            raw = current + (increment * rpeMultiplier)
        } else {
            let increment = current < 20 ? current * 0.05 : 5.0
            raw = current + (increment * rpeMultiplier)
        }
        return GenerationConstants.Weight.roundToAvailable(raw, equipment: equipment)
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
        experienceLevel: ExperienceLevel = .intermediate,
        goal: TrainingGoal? = nil,
        equipment: [Equipment] = [],
        weightCeilings: [Equipment: Double] = [:]
    ) -> UserExerciseStats {
        let working = completedSets.filter {
            !$0.isWarmup && !$0.isCooldown
                && ($0.reps > 0 || ($0.durationSeconds ?? 0) > 0 || ($0.distanceMeters ?? 0) > 0)
        }
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
            EffortFeedbackMapping.metPrescription(completed: set, planned: planned).hitTop
        }
        let missedMin = zip(working, workingPlanned).contains { set, planned in
            EffortFeedbackMapping.metPrescription(completed: set, planned: planned).missedMin
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
            stats.deloadStartedAt = existing.deloadStartedAt
            stats.returningFromBreak = existing.returningFromBreak
            stats.consecutiveHighVolumeWeeks = existing.consecutiveHighVolumeWeeks
            stats.isOrphaned = existing.isOrphaned
            stats.goalAtLastUpdate = existing.goalAtLastUpdate
            stats.lastMaxEffortAt = existing.lastMaxEffortAt
            stats.sessionsSinceMaxEffort = existing.sessionsSinceMaxEffort + 1
        }

        var maxEffortSet: CompletedSet?
        for (completed, planned) in zip(working, workingPlanned) where planned.isMaxEffort {
            maxEffortSet = completed
        }
        if let maxEffortSet,
           let recalibrated = MaxEffortPlanner.recalibratedWeight(
               from: maxEffortSet,
               equipment: equipment,
               ceilings: weightCeilings
           ) {
            if let weight = maxEffortSet.weightKg {
                stats.estimatedOneRepMax = estimateOneRepMax(weight: weight, reps: maxEffortSet.reps)
            }
            stats.suggestedNextWeightKg = recalibrated
            stats.lastMaxEffortAt = Date()
            stats.sessionsSinceMaxEffort = 0
            VolumeTracker.recordSession(on: &stats)
            DeloadDetector.updateDeloadState(stats: &stats)
            if let goal {
                stats.goalAtLastUpdate = goal
            }
            return stats
        }

        if let goal {
            stats.goalAtLastUpdate = goal
        }

        VolumeTracker.recordSession(on: &stats)
        DeloadDetector.updateDeloadState(stats: &stats)

        if stats.returningFromBreak, existing?.returningFromBreak == true {
            stats.returningFromBreak = false
        }

        if let lastWeight = lastWeight {
            let volumeCap = VolumeCapCalculator.adjustedWeeklySetCap(
                experience: experienceLevel,
                soreness: .none
            )
            let avgRPE = averageLoggedRPE(from: working)
            if hitTop || missedMin {
                stats.suggestedNextWeightKg = nextWeight(
                    currentWeight: lastWeight,
                    completedAllSetsAtTopRange: hitTop,
                    missedMinimumReps: missedMin,
                    averageLoggedRPE: avgRPE,
                    equipment: equipment
                )
            } else {
                stats.suggestedNextWeightKg = nextWeight(
                    current: lastWeight,
                    stats: stats,
                    volumeCap: volumeCap,
                    setCountThisWeek: stats.weeklyMaxSets,
                    bodyweight: bodyweightKg,
                    equipment: equipment
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

        return GenerationConstants.Weight.roundToAvailable(
            baseWeight * experienceFactor,
            equipment: exercise.equipment
        )
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

    /// Estimates working sets in the trailing 7×24h window ending at `now`.
    static func weeklyVolumeEstimate(
        recentWorkouts: [WorkoutSessionSummary],
        endingAt now: Date = Date()
    ) -> Int {
        recentWorkouts
            .filter { GenerationConstants.Time.isInRollingWindow($0.completedAt, endingAt: now) }
            .reduce(0) { $0 + $1.totalSets }
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
            partial + volumeContribution(for: set)
        }
    }

    static func volumeContribution(for set: CompletedSet) -> Double {
        if set.reps > 0 {
            return (set.weightKg ?? 0) * Double(set.reps)
        }
        if let seconds = set.durationSeconds, seconds > 0 {
            return (set.weightKg ?? 0) * Double(seconds) / 60.0
        }
        if let meters = set.distanceMeters, meters > 0 {
            return (set.weightKg ?? 0) * meters / 1000.0
        }
        return 0
    }

    static func completedSetCount(session: WorkoutSession) -> Int {
        session.exercises.flatMap(\.completedSets).count
    }

    static func trainedMuscleGroups(session: WorkoutSession, exerciseMap: [String: Exercise]) -> [MuscleGroup] {
        var groups = Set<MuscleGroup>()
        for workoutExercise in session.exercises where !workoutExercise.wasSkipped {
            guard let exercise = exerciseMap[workoutExercise.exerciseId] else { continue }
            groups.formUnion(exercise.primaryMuscles)
        }
        return MuscleGroup.allCases.filter { groups.contains($0) }
    }

    static func formattedElapsed(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}

