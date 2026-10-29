import Foundation

enum RecoveryCalculator {
    static func defaultStates() -> [MuscleRecoveryState] {
        MuscleGroup.allCases.map {
            MuscleRecoveryState(
                muscleGroup: $0,
                recoveryPercentage: GenerationConstants.Recovery.defaultMuscleRecovery,
                lastTrainedAt: nil,
                accumulatedFatigue: 0,
                fitness: 0,
                fatigue: 0
            )
        }
    }

    /// Keeps the lowest recovery per muscle, clamps to 0–100%, and backfills missing groups at 100%.
    static func normalizeStates(_ states: [MuscleRecoveryState]) -> [MuscleRecoveryState] {
        var byMuscle: [MuscleGroup: MuscleRecoveryState] = [:]
        for state in states {
            var normalized = state
            normalized.syncPreparedness()
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
                accumulatedFatigue: 0,
                fitness: 0,
                fatigue: 0
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
        let fatigueRate = experienceLevel.recoveryRatePerHour
        let fitnessRate = fatigueRate / GenerationConstants.Recovery.fitnessToFatigueDecayRatio
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
            updatedState.fatigue = max(0, state.fatigue - hours * fatigueRate)
            updatedState.fitness = max(0, state.fitness - hours * fitnessRate)
            updatedState.syncPreparedness()
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
            let workingSets = item.sets.filter { !$0.isWarmup && !$0.isCooldown }
            let intensityMultiplier = item.exercise.resolvedMechanics == .compound ? 1.2 : 0.8
            let effortMultiplier = effortMultiplier(for: workingSets)
            let contributions = muscleContributions(for: item.exercise)

            for (muscle, contribution) in contributions {
                var state = map[muscle] ?? MuscleRecoveryState(
                    muscleGroup: muscle,
                    recoveryPercentage: GenerationConstants.Recovery.defaultMuscleRecovery,
                    lastTrainedAt: nil,
                    accumulatedFatigue: 0,
                    fitness: 0,
                    fatigue: 0
                )
                let setCount = Double(workingSets.count)
                let fatigueDelta = setCount
                    * intensityMultiplier
                    * contribution
                    * effortMultiplier
                    * GenerationConstants.Recovery.fatiguePerHardSet
                let fitnessDelta = setCount
                    * intensityMultiplier
                    * contribution
                    * GenerationConstants.Recovery.fitnessPerHardSet
                state.fatigue += fatigueDelta
                state.fitness += fitnessDelta
                state.lastTrainedAt = Date()
                state.syncPreparedness()
                map[muscle] = state
            }
        }
        return MuscleGroup.allCases.compactMap { map[$0] }
    }

    static func effortMultiplier(for sets: [CompletedSet]) -> Double {
        let rpes = sets.compactMap(\.rpe)
        guard let average = rpes.isEmpty ? nil : rpes.reduce(0, +) / Double(rpes.count) else {
            return 0.85
        }
        return min(1.2, max(0.6, average / 10.0))
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
            updated.fatigue += penalty
            updated.syncPreparedness()
            return updated
        }
    }

    /// Global readiness offset applied as fatigue when assembling generation input.
    static func applyManualReadiness(
        states: [MuscleRecoveryState],
        manualReadiness: Double?
    ) -> [MuscleRecoveryState] {
        guard let manualReadiness else { return states }
        let clamped = min(100, max(0, manualReadiness))
        let deficit = max(0, 100 - clamped)
        guard deficit > 0 else { return states }
        return states.map { state in
            var updated = state
            updated.fatigue += deficit * 0.25
            updated.syncPreparedness()
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
    static func averageLoggedRPE(from sets: [CompletedSet], trustHistoric: Bool = true) -> Double? {
        EffortFeedbackMapping.averageEffectiveRPE(from: sets, trustHistoric: trustHistoric)
    }

    /// Retains sets across the current + previous rolling week (capped) so weekly volume is accurate.
    static func prunedRecentSets(_ sets: [CompletedSet], endingAt now: Date = Date()) -> [CompletedSet] {
        let cutoff = now.addingTimeInterval(-GenerationConstants.Volume.recentSetsRetentionSeconds)
        let inWindow = sets.filter { $0.completedAt >= cutoff }
        let source = inWindow.isEmpty ? sets : inWindow
        return Array(source.suffix(GenerationConstants.Volume.maxRecentSetsStored))
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
        if currentWeight < 0 {
            return nextAssistedWeight(
                currentWeight: currentWeight,
                completedAllSetsAtTopRange: completedAllSetsAtTopRange,
                missedMinimumReps: missedMinimumReps,
                averageLoggedRPE: averageLoggedRPE,
                equipment: equipment
            )
        }
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

    /// Assisted loads are negative. Hitting the top of the range reduces assistance (toward zero).
    /// Missing reps or a deload adds assistance (more negative). Multiplying a negative load
    /// by 0.95 would make the next session harder.
    private static func nextAssistedWeight(
        currentWeight: Double,
        completedAllSetsAtTopRange: Bool,
        missedMinimumReps: Bool,
        averageLoggedRPE: Double?,
        equipment: [Equipment]
    ) -> Double {
        let step = GenerationConstants.Weight.barbellIncrementKg
        let raw: Double
        if completedAllSetsAtTopRange {
            let applied = step * rpeProgressionMultiplier(averageLoggedRPE: averageLoggedRPE)
            raw = applied > 0 ? currentWeight + applied : currentWeight
        } else if missedMinimumReps {
            let veryHard = (averageLoggedRPE ?? 0) >= GenerationConstants.Progression.veryHardRPEThreshold
            raw = currentWeight - (veryHard ? step * 2 : step)
        } else {
            raw = currentWeight
        }
        let rounded = GenerationConstants.Weight.roundToAvailable(raw, equipment: equipment)
        return max(rounded, GenerationConstants.Validation.minLoggedWeightKg)
    }

    /// Historical volume-trend formula. Workout planning uses SessionLoadPlanner.
    static func nextWeight(
        current: Double,
        stats: UserExerciseStats,
        muscleVolumeCompletion: Double,
        bodyweight: Double,
        equipment: [Equipment] = []
    ) -> Double {
        let averageLoggedRPE = averageLoggedRPE(from: stats.recentSets)
        let rpeMultiplier = rpeProgressionMultiplier(averageLoggedRPE: averageLoggedRPE)
        if current < 0 {
            let easeOff = stats.isInDeloadWeek
                || stats.returningFromBreak
                || muscleVolumeCompletion >= GenerationConstants.Volume.overloadHoldCompletionFraction
            return nextAssistedWeight(
                currentWeight: current,
                completedAllSetsAtTopRange: !easeOff && stats.volumeTrend != .decreasing,
                missedMinimumReps: easeOff,
                averageLoggedRPE: averageLoggedRPE,
                equipment: equipment
            )
        }
        let raw: Double
        // If in deload week, reduce weight by 10%
        if stats.isInDeloadWeek {
            raw = current * 0.9
        } else if stats.returningFromBreak {
            raw = current * GenerationConstants.Deload.reEntryWeightMultiplier
        } else if stats.volumeTrend == .decreasing {
            raw = current
        } else if muscleVolumeCompletion >= GenerationConstants.Volume.overloadHoldCompletionFraction {
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

    /// Legacy overload gate kept for call sites that still pass program-wide caps.
    static func nextWeight(
        current: Double,
        stats: UserExerciseStats,
        volumeCap: Int,
        setCountThisWeek: Int,
        bodyweight: Double,
        equipment: [Equipment] = []
    ) -> Double {
        let completion = volumeCap > 0 ? Double(setCountThisWeek) / Double(volumeCap) : 0
        return nextWeight(
            current: current,
            stats: stats,
            muscleVolumeCompletion: completion,
            bodyweight: bodyweight,
            equipment: equipment
        )
    }

    static func estimateOneRepMax(weight: Double, reps: Int) -> Double {
        guard weight > 0 else { return 0 }
        guard reps > 0 else { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }

    static func progressionNote(name: String, nextLoad: Double, unit: String) -> String {
        let number = nextLoad.rounded() == nextLoad
            ? String(Int(nextLoad))
            : String(format: "%.1f", nextLoad)
        let trimmed = unit.trimmingCharacters(in: .whitespaces)
        return "\(name): try \(number) \(trimmed) next session."
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
        weightCeilings: [Equipment: Double] = [:],
        trustHistoricEffortFeedback: Bool = true,
        sessionMode: SessionMode = .standard,
        countsExternalKilograms: Bool = true
    ) -> UserExerciseStats {
        let working = completedSets.filter {
            !$0.isWarmup && !$0.isCooldown
                && ($0.reps > 0 || ($0.durationSeconds ?? 0) > 0 || ($0.distanceMeters ?? 0) > 0)
        }
        let last = working.last
        let lastWeight = last?.weightKg
        let lastReps = last?.reps
        let e1rm: Double? = {
            guard countsExternalKilograms else { return existing?.estimatedOneRepMax }
            guard let w = last, let weight = w.weightKg, weight > 0 else {
                return existing?.estimatedOneRepMax
            }
            return estimateOneRepMax(weight: weight, reps: w.reps)
        }()
        let sessionBest = working.map { max(0, $0.weightKg ?? 0) * Double($0.reps) }.max() ?? 0
        let bestVolume = countsExternalKilograms && sessionBest > 0
            ? sessionBest
            : existing?.bestVolumeSet

        let workingPlanned = plannedSets.filter { !$0.isWarmup && !$0.isCooldown }
        let hitTop = working.count == workingPlanned.count && zip(working, workingPlanned).allSatisfy { set, planned in
            EffortFeedbackMapping.metPrescription(completed: set, planned: planned).hitTop
        }
        let missedMin = zip(working, workingPlanned).contains { set, planned in
            EffortFeedbackMapping.metPrescription(completed: set, planned: planned).missedMin
        }

        var recentSets = (existing?.recentSets ?? []) + working
        recentSets = Self.prunedRecentSets(recentSets)

        var stats = UserExerciseStats(
            exerciseId: exerciseId,
            lastWeightKg: lastWeight,
            lastReps: lastReps,
            suggestedNextWeightKg: nil,
            estimatedOneRepMax: e1rm,
            bestVolumeSet: bestVolume,
            recentSets: recentSets,
            preferredRepRangeMin: workingPlanned.first?.targetRepsMin ?? existing?.preferredRepRangeMin ?? 8,
            preferredRepRangeMax: workingPlanned.first?.targetRepsMax ?? existing?.preferredRepRangeMax ?? 12,
            preferVariation: existing?.preferVariation ?? false
        )

        if let existing {
            carryForwardVolumeState(from: existing, to: &stats)
        }
        stats.updatedAt = Date()

        if !countsExternalKilograms {
            return recordSessionWithoutKilogramProgression(
                stats: stats,
                existing: existing,
                goal: goal,
                trustHistoricEffortFeedback: trustHistoricEffortFeedback
            )
        }

        let loadWasReduced = sessionMode == .recovery
            || existing?.isInDeloadWeek == true
            || existing?.returningFromBreak == true
        if loadWasReduced {
            stats.suggestedNextWeightKg = existing?.suggestedNextWeightKg
            if let goal {
                stats.goalAtLastUpdate = goal
            }
            VolumeTracker.recordSession(on: &stats)
            DeloadDetector.updateDeloadState(
                stats: &stats,
                trustHistoricEffortFeedback: trustHistoricEffortFeedback
            )
            if stats.returningFromBreak, existing?.returningFromBreak == true {
                stats.returningFromBreak = false
            }
            return stats
        }

        var maxEffortSet: CompletedSet?
        for (completed, planned) in zip(working, workingPlanned) where planned.isMaxEffort {
            maxEffortSet = completed
        }
        if let maxEffortSet,
           let effortWeight = maxEffortSet.weightKg,
           effortWeight > 0,
           let recalibrated = MaxEffortPlanner.recalibratedWeight(
               from: maxEffortSet,
               equipment: equipment,
               ceilings: weightCeilings
           ) {
            stats.estimatedOneRepMax = estimateOneRepMax(weight: effortWeight, reps: maxEffortSet.reps)
            stats.suggestedNextWeightKg = recalibrated
            stats.lastMaxEffortAt = Date()
            stats.sessionsSinceMaxEffort = 0
            VolumeTracker.recordSession(on: &stats)
            DeloadDetector.updateDeloadState(
                stats: &stats,
                trustHistoricEffortFeedback: trustHistoricEffortFeedback
            )
            if let goal {
                stats.goalAtLastUpdate = goal
            }
            return stats
        }

        if let goal {
            stats.goalAtLastUpdate = goal
        }

        VolumeTracker.recordSession(on: &stats)
        DeloadDetector.updateDeloadState(
            stats: &stats,
            trustHistoricEffortFeedback: trustHistoricEffortFeedback
        )

        if stats.returningFromBreak, existing?.returningFromBreak == true {
            stats.returningFromBreak = false
        }

        if let lastWeight = lastWeight {
            applyProgressionPolicy(
                to: &stats,
                lastWeight: lastWeight,
                workingSets: working,
                hitTopOfRepRange: hitTop,
                missedMinimumReps: missedMin,
                goal: goal ?? .buildMuscle,
            equipment: equipment,
            weightCeilings: weightCeilings,
            trustHistoric: trustHistoricEffortFeedback,
            experience: experienceLevel
        )
        }

        return stats
    }

    private static func carryForwardVolumeState(from existing: UserExerciseStats, to stats: inout UserExerciseStats) {
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

    /// Resistance levels are not kilograms. Keep the previous e1RM and suggested load.
    private static func recordSessionWithoutKilogramProgression(
        stats: UserExerciseStats,
        existing: UserExerciseStats?,
        goal: TrainingGoal?,
        trustHistoricEffortFeedback: Bool
    ) -> UserExerciseStats {
        var stats = stats
        stats.lastWeightKg = existing?.lastWeightKg
        stats.lastReps = existing?.lastReps
        stats.bestVolumeSet = existing?.bestVolumeSet
        stats.suggestedNextWeightKg = existing?.suggestedNextWeightKg
        stats.estimatedOneRepMax = existing?.estimatedOneRepMax
        if let goal {
            stats.goalAtLastUpdate = goal
        }
        VolumeTracker.recordSession(on: &stats)
        DeloadDetector.updateDeloadState(
            stats: &stats,
            trustHistoricEffortFeedback: trustHistoricEffortFeedback
        )
        return stats
    }

    static func reapplyEffortTrust(stats: inout UserExerciseStats, trustHistoric: Bool) {
        guard let lastWeight = stats.lastWeightKg, let lastReps = stats.lastReps else { return }
        let workingSets = stats.recentSets.filter(EffortFeedbackMapping.isWorkingSet)
        // Explicit and skipped sets keep their meaning when the trust flag flips.
        guard workingSets.contains(where: { $0.effortFeedbackStatus == .unknown }) else { return }
        // Do not overwrite a max-effort recalibration.
        if stats.lastMaxEffortAt != nil, stats.sessionsSinceMaxEffort == 0 { return }

        let repMin = stats.preferredRepRangeMin
        let repMax = stats.preferredRepRangeMax
        let preferVariation = stats.preferVariation
        defer {
            // Replay may change the suggested load only, never the rep range or variation flag.
            stats.preferredRepRangeMin = repMin
            stats.preferredRepRangeMax = repMax
            stats.preferVariation = preferVariation
        }
        applyProgressionPolicy(
            to: &stats,
            lastWeight: lastWeight,
            workingSets: workingSets,
            hitTopOfRepRange: lastReps >= stats.preferredRepRangeMax,
            missedMinimumReps: lastReps < stats.preferredRepRangeMin,
            goal: stats.goalAtLastUpdate ?? .buildMuscle,
            equipment: [],
            weightCeilings: [:],
            trustHistoric: trustHistoric,
            experience: .intermediate
        )
    }

    private static func applyProgressionPolicy(
        to stats: inout UserExerciseStats,
        lastWeight: Double,
        workingSets: [CompletedSet],
        hitTopOfRepRange: Bool,
        missedMinimumReps: Bool,
        goal: TrainingGoal,
        equipment: [Equipment],
        weightCeilings: [Equipment: Double],
        trustHistoric: Bool = true,
        experience: ExperienceLevel = .intermediate
    ) {
        let avgRPE = averageLoggedRPE(from: workingSets, trustHistoric: trustHistoric)
        let action = ProgressionPolicy.action(
            goal: goal,
            hitTopOfRepRange: hitTopOfRepRange,
            missedMinimumReps: missedMinimumReps,
            stalledSessions: ProgressionPolicy.stalledSessionCount(stats: stats)
        )
        switch action {
        case .increaseLoad:
            stats.preferVariation = false
            let range = GenerationConstants.Prescription.repRange(for: goal, experience: experience)
            stats.preferredRepRangeMin = range.min
            stats.preferredRepRangeMax = range.max
            stats.suggestedNextWeightKg = nextWeight(
                currentWeight: lastWeight,
                completedAllSetsAtTopRange: true,
                missedMinimumReps: false,
                averageLoggedRPE: avgRPE,
                equipment: equipment
            )
        case .reduceLoad:
            stats.suggestedNextWeightKg = nextWeight(
                currentWeight: lastWeight,
                completedAllSetsAtTopRange: false,
                missedMinimumReps: true,
                averageLoggedRPE: avgRPE,
                equipment: equipment
            )
        case .hold:
            stats.suggestedNextWeightKg = GenerationConstants.Weight.roundToAvailable(
                lastWeight,
                equipment: equipment
            )
        case .holdLoadIncreaseReps:
            stats.suggestedNextWeightKg = GenerationConstants.Weight.roundToAvailable(
                lastWeight,
                equipment: equipment
            )
            if stats.preferredRepRangeMin < stats.preferredRepRangeMax {
                stats.preferredRepRangeMin += 1
            }
        case .preferVariation:
            stats.preferVariation = true
            stats.suggestedNextWeightKg = GenerationConstants.Weight.roundToAvailable(
                lastWeight,
                equipment: equipment
            )
        }
        if let suggested = stats.suggestedNextWeightKg {
            stats.suggestedNextWeightKg = GenerationConstants.Weight.roundToAvailable(
                suggested,
                equipment: equipment,
                ceilings: weightCeilings
            )
        }
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

enum ExerciseSegmentFill: Equatable {
    case complete
    case current
    case remaining
}

struct ExerciseSegmentStyle: Equatable {
    var completedFraction: Double
    /// True for the exercise the athlete is on, including when that segment is already fully green.
    var showsCurrent: Bool
}

struct ExerciseSetProgress: Equatable {
    var completedSets: Int
    var plannedSets: Int
}

enum WorkoutAdvanceDecision: Equatable {
    case goToExercise(index: Int)
    case confirmEnd
}

struct WorkoutEndConfirmationCopy: Equatable {
    let title: String
    let message: String
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

    /// Segment color for callers that only know done vs not done.
    /// Completion wins over position, so an exercise finished out of order stays green
    /// and an earlier exercise that still has sets stays grey.
    static func exerciseSegmentFill(
        index: Int,
        currentIndex: Int,
        isComplete: Bool
    ) -> ExerciseSegmentFill {
        if isComplete { return .complete }
        if index == currentIndex { return .current }
        return .remaining
    }

    /// How one exercise segment should paint.
    /// Green is the share of sets already logged, including partial credit.
    /// The current exercise keeps a red remainder, or a red cap once it is full,
    /// so position stays visible after that segment turns green.
    static func exerciseSegmentStyle(
        completedSets: Int,
        plannedSets: Int,
        isCurrent: Bool
    ) -> ExerciseSegmentStyle {
        let planned = max(plannedSets, 0)
        let completed = min(max(completedSets, 0), planned == 0 ? 0 : planned)
        let fraction = planned == 0 ? 0 : Double(completed) / Double(planned)
        return ExerciseSegmentStyle(completedFraction: fraction, showsCurrent: isCurrent)
    }

    /// Sets whose `setIndex` lands on a planned row. Duplicate indexes count once.
    static func loggedSetCount(_ exercise: WorkoutExercise) -> Int {
        let planned = exercise.plannedSets.count
        guard planned > 0 else { return 0 }
        let indexes = exercise.completedSets.map(\.setIndex).filter { (0..<planned).contains($0) }
        return Set(indexes).count
    }

    /// First planned row that does not yet have a completed set. Skips holes instead of `completedSets.count`.
    static func firstIncompleteSetIndex(plannedCount: Int, completedSetIndexes: Set<Int>) -> Int? {
        guard plannedCount > 0 else { return nil }
        return (0..<plannedCount).first { !completedSetIndexes.contains($0) }
    }

    /// Next exercise that still needs sets, searching forward and then wrapping.
    /// Nil when every exercise is logged or skipped.
    static func nextIncompleteExerciseIndex(after index: Int, in exercises: [WorkoutExercise]) -> Int? {
        guard !exercises.isEmpty else { return nil }
        if !exercises.indices.contains(index) {
            return exercises.firstIndex(where: needsSetsLogged)
        }
        for offset in 1...exercises.count {
            let candidate = (index + offset) % exercises.count
            if needsSetsLogged(exercises[candidate]) { return candidate }
        }
        return nil
    }

    /// Saved exercise when it is still in the session; otherwise the first exercise that still has sets to log.
    static func currentExerciseIndex(for session: WorkoutSession) -> Int {
        if let id = session.currentExerciseId,
           let idx = session.exercises.firstIndex(where: { $0.id == id }),
           !session.exercises[idx].wasSkipped {
            return idx
        }
        if let idx = session.exercises.firstIndex(where: needsSetsLogged) {
            return idx
        }
        if let last = session.exercises.lastIndex(where: { !$0.wasSkipped }) {
            return last
        }
        return max(0, session.exercises.count - 1)
    }

    static func completedVolumeKg(
        session: WorkoutSession,
        exerciseMap: [String: Exercise] = [:]
    ) -> Double {
        session.exercises.reduce(0) { partial, exercise in
            let semantics = exerciseMap[exercise.exerciseId]?.resolvedWeightDisplaySemantics
                ?? ExerciseMetadataResolver.resolvedWeightDisplaySemantics(exerciseId: exercise.exerciseId)
            let counts = semantics.countsTowardVolumeKg
            return partial + exercise.completedSets.reduce(0) { setPartial, set in
                setPartial + volumeContribution(for: set, externalLoadCounts: counts)
            }
        }
    }

    static func volumeContribution(for set: CompletedSet, externalLoadCounts: Bool = true) -> Double {
        let raw = externalLoadCounts ? (set.weightKg ?? 0) : 0
        let load = max(0, raw)
        if set.reps > 0 {
            return load * Double(set.reps)
        }
        if let seconds = set.durationSeconds, seconds > 0 {
            return load * Double(seconds) / 60.0
        }
        if let meters = set.distanceMeters, meters > 0 {
            return load * meters / 1000.0
        }
        return 0
    }

    static func completedSetCount(session: WorkoutSession) -> Int {
        session.exercises.reduce(0) { $0 + loggedSetCount($1) }
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

    /// Wall-clock remaining rest. UI must re-evaluate this each second (e.g. `TimelineView`).
    static func restSecondsRemaining(until end: Date, at now: Date = Date()) -> Int {
        max(0, Int(ceil(end.timeIntervalSince(now))))
    }

    /// Non-skipped exercise that still has planned sets to log.
    static func needsSetsLogged(_ exercise: WorkoutExercise) -> Bool {
        !exercise.wasSkipped && loggedSetCount(exercise) < exercise.plannedSets.count
    }

    static func isExerciseComplete(_ exercise: WorkoutExercise) -> Bool {
        !exercise.wasSkipped && !needsSetsLogged(exercise)
    }

    static func isSessionFullyLogged(_ session: WorkoutSession) -> Bool {
        !session.exercises.contains(where: needsSetsLogged)
    }

    static func incompleteExerciseCount(in session: WorkoutSession) -> Int {
        session.exercises.filter(needsSetsLogged).count
    }

    static func firstIncompleteExerciseIndex(in session: WorkoutSession) -> Int? {
        session.exercises.firstIndex(where: needsSetsLogged)
    }

    static func advanceDecision(
        session: WorkoutSession,
        currentExerciseIndex: Int
    ) -> WorkoutAdvanceDecision {
        guard let next = nextIncompleteExerciseIndex(after: currentExerciseIndex, in: session.exercises) else {
            return .confirmEnd
        }
        return .goToExercise(index: next)
    }

    static func endConfirmationCopy(incompleteExerciseCount: Int) -> WorkoutEndConfirmationCopy {
        if incompleteExerciseCount <= 0 {
            return WorkoutEndConfirmationCopy(
                title: "Finish Workout?",
                message: "All sets logged. Ready to end this session?"
            )
        }
        let noun = incompleteExerciseCount == 1 ? "exercise" : "exercises"
        return WorkoutEndConfirmationCopy(
            title: "End Workout?",
            message: "\(incompleteExerciseCount) \(noun) still incomplete. Logged sets will be saved."
        )
    }
}
