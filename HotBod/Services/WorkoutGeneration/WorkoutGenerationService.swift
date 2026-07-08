import Foundation

final class RulesWorkoutGenerationService: WorkoutGenerationService, Sendable {
    private let exerciseRepo: any ExerciseRepository

    init(exerciseRepository: any ExerciseRepository = LocalExerciseRepository()) {
        self.exerciseRepo = exerciseRepository
    }

    func generate(input: WorkoutGenerationInput) async throws -> GeneratedWorkout {
        let allExercises = try await exerciseRepo.fetchAll()

        let sessionMode = shouldUseRecoveryMode(input: input) ? SessionMode.recovery : .standard
        let targetSelection = sessionMode == .recovery
            ? (muscles: selectRecoveryTargetMuscles(input: input), avoidedOverride: false)
            : selectTargetMuscles(input: input)

        let ladder: [CandidateFilterOptions] = [
            CandidateFilterOptions(),
            CandidateFilterOptions(includeAvoided: true),
            CandidateFilterOptions(includeAvoided: true, relaxDifficultyPenalty: true)
        ]

        var chosenOptions = ladder[0]
        var available = filteredExercises(
            allExercises,
            input: input,
            avoidedOverride: targetSelection.avoidedOverride,
            options: chosenOptions
        )

        for options in ladder.dropFirst() where available.count < GenerationConstants.Targeting.minCandidatesBeforeRelaxation {
            let relaxed = filteredExercises(
                allExercises,
                input: input,
                avoidedOverride: targetSelection.avoidedOverride,
                options: options
            )
            if relaxed.count >= GenerationConstants.Targeting.minCandidatesBeforeRelaxation {
                chosenOptions = options
                available = relaxed
                break
            }
            if relaxed.count > available.count {
                chosenOptions = options
                available = relaxed
            }
        }

        let minExercises = sessionMode == .recovery
            ? GenerationConstants.RecoverySession.minExercises
            : GenerationConstants.Session.minStandardExercises

        if available.count < minExercises {
            let blockers = countExerciseBlockers(allExercises: allExercises, input: input)
            throw GenerationFailure.insufficientExercises(
                available: available.count,
                blockedByInjury: blockers.injury,
                blockedByEquipment: blockers.equipment
            )
        }

        return try buildWorkout(
            available: available,
            allExercises: allExercises,
            input: input,
            sessionMode: sessionMode,
            targetSelection: targetSelection,
            filterOptions: chosenOptions
        )
    }

    private struct CandidateFilterOptions: Equatable {
        var includeAvoided = false
        var relaxDifficultyPenalty = false
    }

    private func filteredExercises(
        _ allExercises: [Exercise],
        input: WorkoutGenerationInput,
        avoidedOverride: Bool,
        options: CandidateFilterOptions
    ) -> [Exercise] {
        allExercises.filter { exercise in
            (!exercise.isAvoided || options.includeAvoided) &&
            EquipmentFilter.isExerciseAvailable(exercise, availableEquipment: input.availableEquipment) &&
            !GenerationConstants.violatesInjuries(exercise, injuries: input.injuries) &&
            (avoidedOverride || !exercise.primaryMuscles.contains(where: { input.avoidedMuscleGroups.contains($0) }))
        }
    }

    private func countExerciseBlockers(
        allExercises: [Exercise],
        input: WorkoutGenerationInput
    ) -> (injury: Int, equipment: Int) {
        var injury = 0
        var equipment = 0
        for exercise in allExercises {
            let blockedByInjury = GenerationConstants.violatesInjuries(exercise, injuries: input.injuries)
            let blockedByEquipment = !EquipmentFilter.isExerciseAvailable(
                exercise,
                availableEquipment: input.availableEquipment
            )
            if blockedByInjury { injury += 1 }
            if blockedByEquipment { equipment += 1 }
        }
        return (injury, equipment)
    }

    private func buildWorkout(
        available: [Exercise],
        allExercises: [Exercise],
        input: WorkoutGenerationInput,
        sessionMode: SessionMode,
        targetSelection: (muscles: [MuscleGroup], avoidedOverride: Bool),
        filterOptions: CandidateFilterOptions
    ) throws -> GeneratedWorkout {
        let targetMuscles = targetSelection.muscles
        let favoriteIds = Set(input.userPreferences.favoriteExerciseIds)

        let selection = sessionMode == .recovery
            ? selectRecoveryExercises(
                from: available,
                targetMuscles: targetMuscles,
                stats: input.exerciseStats,
                avoidIds: Set(input.userPreferences.avoidExerciseIds),
                preferVariation: input.userPreferences.preferVariation,
                favoriteIds: favoriteIds,
                relaxDifficultyPenalty: filterOptions.relaxDifficultyPenalty
            )
            : selectExercises(
                from: available,
                targetMuscles: targetMuscles,
                experience: input.experienceLevel,
                durationMinutes: input.targetDurationMinutes,
                stats: input.exerciseStats,
                avoidIds: Set(input.userPreferences.avoidExerciseIds),
                preferVariation: input.userPreferences.preferVariation,
                favoriteIds: favoriteIds,
                relaxDifficultyPenalty: filterOptions.relaxDifficultyPenalty
            )

        var planned = selection.exercises.enumerated().map { index, exercise in
            planExercise(
                exercise,
                orderIndex: index,
                input: input,
                sessionMode: sessionMode
            )
        }

        let exerciseMap = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) })
        if sessionMode == .standard {
            WorkoutGenerationAlgorithms.trimToDuration(
                planned: &planned,
                scores: selection.scores,
                targetMuscles: targetMuscles,
                exerciseMap: exerciseMap,
                targetDurationMinutes: input.targetDurationMinutes
            )
        }

        let title = sessionMode == .recovery
            ? "Recovery Session"
            : WorkoutGenerationAlgorithms.workoutTitle(
                muscles: targetMuscles,
                goal: input.goal,
                split: input.userProfile.preferredSplit,
                focus: input.splitDayFocus
            )
        let duration = WorkoutGenerationAlgorithms.estimateDurationMinutes(planned: planned)
        let rationale = sessionMode == .recovery
            ? "Recovery session — reduced volume and intensity based on soreness and fatigue."
            : buildRationale(input: input, muscles: targetMuscles)

        var workout = GeneratedWorkout(
            id: UUID(),
            title: title,
            estimatedDurationMinutes: duration,
            focus: targetMuscles,
            exercises: planned,
            rationale: rationale,
            safetyNotes: input.injuries.filter { $0 != .none }.isEmpty ? [] : ["Movements adjusted for reported limitations."],
            generatedBy: .rulesEngine,
            createdAt: Date(),
            sessionMode: sessionMode,
            splitDayFocus: input.splitDayFocus
        )

        if filterOptions.includeAvoided {
            workout.safetyNotes.append(GenerationConstants.Targeting.avoidedExercisesRelaxationMessage)
        }
        if filterOptions.relaxDifficultyPenalty {
            workout.safetyNotes.append(GenerationConstants.Targeting.difficultyRelaxationMessage)
        }

        if let uncoveredWarning = WorkoutGenerationAlgorithms.uncoveredMuscleWarning(selection.uncoveredMuscles) {
            workout.safetyNotes.append(uncoveredWarning)
        }

        var validation = WorkoutValidator.validate(workout: workout, input: input, exercises: allExercises)
        if let uncoveredWarning = WorkoutGenerationAlgorithms.uncoveredMuscleWarning(selection.uncoveredMuscles) {
            validation = WorkoutValidationResult(
                isValid: validation.isValid,
                errors: validation.errors,
                warnings: validation.warnings + [uncoveredWarning],
                suggestions: validation.suggestions
            )
        }
        if targetSelection.avoidedOverride {
            workout.safetyNotes.append(GenerationConstants.Targeting.avoidedMusclesOverrideMessage)
            validation = WorkoutValidationResult(
                isValid: validation.isValid,
                errors: validation.errors,
                warnings: validation.warnings + [GenerationConstants.Targeting.avoidedMusclesOverrideMessage],
                suggestions: validation.suggestions
            )
        }
        if !validation.isValid {
            workout.safetyNotes.append(contentsOf: validation.errors)
        }
        return workout
    }

    func validate(workout: GeneratedWorkout, input: WorkoutGenerationInput) -> WorkoutValidationResult {
        WorkoutValidator.validate(workout: workout, input: input, exercises: (try? ExerciseSeedLoader.load()) ?? [])
    }

    // MARK: - Session mode

    private func shouldUseRecoveryMode(input: WorkoutGenerationInput) -> Bool {
        if input.readiness?.soreness == .severe { return true }
        return GenerationConstants.Recovery.averageRecovery(in: input.muscleRecovery)
            < GenerationConstants.Recovery.recoverySessionAvgThreshold
    }

    private func selectRecoveryTargetMuscles(input: WorkoutGenerationInput) -> [MuscleGroup] {
        Array(
            MuscleGroup.allCases
                .sorted {
                    GenerationConstants.Recovery.recovery(for: $0, in: input.muscleRecovery) >
                    GenerationConstants.Recovery.recovery(for: $1, in: input.muscleRecovery)
                }
                .prefix(GenerationConstants.RecoverySession.targetMuscleCount)
        )
    }

    // MARK: - Target muscles (standard)

    private func selectTargetMuscles(input: WorkoutGenerationInput) -> (muscles: [MuscleGroup], avoidedOverride: Bool) {
        var recovery = input.muscleRecovery
        if input.readiness?.soreness == .severe {
            recovery = recovery.mapValues { max(0, $0 - GenerationConstants.Recovery.severeSorenessRecoveryPenalty) }
        } else if input.readiness?.soreness == .moderate {
            recovery = recovery.mapValues { max(0, $0 - GenerationConstants.Recovery.moderateSorenessRecoveryPenalty) }
        }
        applySleepRecoveryPenalty(readiness: input.readiness, recovery: &recovery)

        var avoidedOverride = false

        if let focus = input.splitDayFocus {
            let splitMuscles = TrainingSchedule.muscles(for: focus)
            let (eligibleSplit, override) = applyAvoidedMuscles(splitMuscles, avoided: input.avoidedMuscleGroups)
            avoidedOverride = override
            let ready = eligibleSplit
                .filter {
                    GenerationConstants.Recovery.recovery(for: $0, in: recovery) >= GenerationConstants.Recovery.splitMuscleMinRecovery
                }
                .sorted { recoverySortKey($0, recovery: recovery, preferred: input.preferredMuscleGroups) >
                    recoverySortKey($1, recovery: recovery, preferred: input.preferredMuscleGroups) }
            if ready.count >= 2 {
                return (Array(ready.prefix(4)), avoidedOverride)
            }
            let fallback = eligibleSplit.sorted {
                recoverySortKey($0, recovery: recovery, preferred: input.preferredMuscleGroups) >
                recoverySortKey($1, recovery: recovery, preferred: input.preferredMuscleGroups)
            }
            return (Array(fallback.prefix(4)), avoidedOverride)
        }

        let recentlyTrained = Set(input.recentWorkouts.prefix(2).flatMap(\.muscleGroups))
        let (eligibleMuscles, override) = applyAvoidedMuscles(
            MuscleGroup.allCases,
            avoided: input.avoidedMuscleGroups
        )
        avoidedOverride = avoidedOverride || override
        let ready = eligibleMuscles
            .filter {
                GenerationConstants.Recovery.recovery(for: $0, in: recovery) >= GenerationConstants.Recovery.readyMuscleMinRecovery
                    && !recentlyTrained.contains($0)
            }
            .sorted {
                recoverySortKey($0, recovery: recovery, preferred: input.preferredMuscleGroups) >
                recoverySortKey($1, recovery: recovery, preferred: input.preferredMuscleGroups)
            }

        if ready.count >= 3 {
            switch input.userProfile.preferredSplit {
            case .upperLower, .pushPullLegs:
                let upper: [MuscleGroup] = [.chest, .back, .shoulders, .biceps, .triceps]
                let lower: [MuscleGroup] = [.quads, .hamstrings, .glutes, .calves]
                let upperAvg = upper.map { GenerationConstants.Recovery.recovery(for: $0, in: recovery) }.reduce(0, +) / Double(upper.count)
                let lowerAvg = lower.map { GenerationConstants.Recovery.recovery(for: $0, in: recovery) }.reduce(0, +) / Double(lower.count)
                let chosen = upperAvg >= lowerAvg ? upper : lower
                let (eligibleChosen, chosenOverride) = applyAvoidedMuscles(chosen, avoided: input.avoidedMuscleGroups)
                avoidedOverride = avoidedOverride || chosenOverride
                let sorted = eligibleChosen.sorted {
                    recoverySortKey($0, recovery: recovery, preferred: input.preferredMuscleGroups) >
                    recoverySortKey($1, recovery: recovery, preferred: input.preferredMuscleGroups)
                }
                return (Array(sorted.prefix(3)), avoidedOverride)
            default:
                return (Array(ready.prefix(4)), avoidedOverride)
            }
        }

        let fallback = eligibleMuscles.sorted {
            recoverySortKey($0, recovery: recovery, preferred: input.preferredMuscleGroups) >
            recoverySortKey($1, recovery: recovery, preferred: input.preferredMuscleGroups)
        }
        return (Array(fallback.prefix(4)), avoidedOverride)
    }

    private func applySleepRecoveryPenalty(readiness: ReadinessInput?, recovery: inout [MuscleGroup: Double]) {
        guard let sleep = readiness?.sleepScore else { return }
        if sleep < GenerationConstants.Recovery.poorSleepScoreThreshold {
            recovery = recovery.mapValues { max(0, $0 - GenerationConstants.Recovery.poorSleepRecoveryPenalty) }
        } else if sleep < GenerationConstants.Recovery.suboptimalSleepScoreThreshold {
            recovery = recovery.mapValues { max(0, $0 - GenerationConstants.Recovery.suboptimalSleepRecoveryPenalty) }
        }
    }

    private func recoverySortKey(
        _ muscle: MuscleGroup,
        recovery: [MuscleGroup: Double],
        preferred: [MuscleGroup]
    ) -> Double {
        let base = GenerationConstants.Recovery.recovery(for: muscle, in: recovery)
        let bonus = preferred.contains(muscle) ? GenerationConstants.Targeting.preferredMuscleRecoveryBonus : 0
        return base + bonus
    }

    private func applyAvoidedMuscles(
        _ candidates: [MuscleGroup],
        avoided: [MuscleGroup]
    ) -> (muscles: [MuscleGroup], overrideTriggered: Bool) {
        guard !avoided.isEmpty else { return (candidates, false) }
        let filtered = candidates.filter { !avoided.contains($0) }
        if filtered.count >= GenerationConstants.Targeting.minCandidatesAfterAvoidance {
            return (filtered, false)
        }
        return (candidates, true)
    }

    // MARK: - Exercise selection

    private func selectExercises(
        from available: [Exercise],
        targetMuscles: [MuscleGroup],
        experience: ExperienceLevel,
        durationMinutes: Int,
        stats: [UserExerciseStats],
        avoidIds: Set<String>,
        preferVariation: Bool = false,
        favoriteIds: Set<String> = [],
        relaxDifficultyPenalty: Bool = false
    ) -> ExerciseSelectionResult {
        let maxExercises = min(
            GenerationConstants.Session.maxExercisesCap,
            max(GenerationConstants.Session.minStandardExercises, durationMinutes / GenerationConstants.Session.minutesPerExerciseDivisor)
        )
        let filtered = available.filter { !avoidIds.contains($0.id) }
        let scored = WorkoutGenerationAlgorithms.scoreExercises(
            filtered,
            targetMuscles: targetMuscles,
            experience: experience,
            stats: stats,
            recoveryBias: false,
            favoriteIds: favoriteIds,
            ignoreDifficultyPenalty: relaxDifficultyPenalty
        )
        let ranked = WorkoutGenerationAlgorithms.rankScored(
            scored,
            preferVariation: preferVariation,
            avoidIds: avoidIds
        )
        return WorkoutGenerationAlgorithms.selectExercises(
            ranked: ranked,
            targetMuscles: targetMuscles,
            maxExercises: maxExercises,
            minExercises: GenerationConstants.Session.minStandardExercises
        )
    }

    private func selectRecoveryExercises(
        from available: [Exercise],
        targetMuscles: [MuscleGroup],
        stats: [UserExerciseStats],
        avoidIds: Set<String>,
        preferVariation: Bool,
        favoriteIds: Set<String> = [],
        relaxDifficultyPenalty: Bool = false
    ) -> ExerciseSelectionResult {
        let filtered = available.filter { !avoidIds.contains($0.id) }
        let scored = WorkoutGenerationAlgorithms.scoreExercises(
            filtered,
            targetMuscles: targetMuscles,
            experience: .intermediate,
            stats: stats,
            recoveryBias: true,
            favoriteIds: favoriteIds,
            ignoreDifficultyPenalty: relaxDifficultyPenalty
        )
        let ranked = WorkoutGenerationAlgorithms.rankScored(
            scored,
            preferVariation: preferVariation,
            avoidIds: avoidIds
        )
        return WorkoutGenerationAlgorithms.selectExercises(
            ranked: ranked,
            targetMuscles: targetMuscles,
            maxExercises: GenerationConstants.RecoverySession.maxExercises,
            minExercises: GenerationConstants.RecoverySession.minExercises
        )
    }

    // MARK: - Set planning

    private func planExercise(
        _ exercise: Exercise,
        orderIndex: Int,
        input: WorkoutGenerationInput,
        sessionMode: SessionMode
    ) -> PlannedExercise {
        let stats = input.exerciseStats.first { $0.exerciseId == exercise.id }
        let repRange = GenerationConstants.Prescription.effectiveRepRange(
            stats: stats,
            goal: input.goal,
            experience: input.experienceLevel
        )
        let minReps = repRange.min
        let maxReps = repRange.max
        let setCount = GenerationConstants.Prescription.setCount(
            experience: input.experienceLevel,
            pattern: exercise.movementPattern
        )

        let soreness = input.readiness?.soreness ?? .none
        let volumeCap = GenerationConstants.Volume.adjustedWeeklySetCap(
            experience: input.experienceLevel,
            soreness: soreness
        )

        var weight: Double
        if sessionMode == .recovery {
            if let stats, let planning = stats.planningWeightKg {
                weight = planning * GenerationConstants.RecoverySession.weightMultiplier
            } else {
                weight = defaultWeight(
                    for: exercise,
                    experience: input.experienceLevel,
                    bodyweightKg: input.userProfile.weightKg
                ) * GenerationConstants.RecoverySession.weightMultiplier
            }
        } else if let stats, let lastWeight = stats.planningWeightKg {
            weight = ProgressiveOverload.nextWeight(
                current: lastWeight,
                stats: stats,
                volumeCap: volumeCap,
                setCountThisWeek: stats.weeklyMaxSets,
                bodyweight: input.userProfile.weightKg ?? GenerationConstants.Session.defaultBodyweightKgFallback,
                equipment: exercise.equipment
            )
        } else {
            weight = defaultWeight(
                for: exercise,
                experience: input.experienceLevel,
                bodyweightKg: input.userProfile.weightKg
            )
        }

        weight = GenerationConstants.Weight.roundToAvailable(weight, equipment: exercise.equipment)
        let plannedWeight: Double? = exercise.usesBodyweightLoading ? nil : weight

        var (intensity, adjustedSetCount) = deloadAdjustment(baseSetCount: setCount, stats: stats)
        var rpeTarget = WorkoutGenerationAlgorithms.rpeTarget(
            sessionMode: sessionMode,
            experience: input.experienceLevel,
            isDeload: stats?.isInDeloadWeek == true,
            sleepScore: input.readiness?.sleepScore
        )

        if stats?.returningFromBreak == true {
            adjustedSetCount = setCount
            intensity = .moderate
            rpeTarget = GenerationConstants.Deload.reEntryRPETarget
        }

        if sessionMode == .recovery {
            adjustedSetCount = max(1, adjustedSetCount - 1)
            intensity = .light
        } else if let sleep = input.readiness?.sleepScore,
                  sleep < GenerationConstants.Recovery.poorSleepScoreThreshold,
                  exercise.resolvedMechanics == .compound {
            adjustedSetCount = max(1, adjustedSetCount - 1)
        }

        let restSeconds = WorkoutGenerationAlgorithms.restSeconds(
            goal: input.goal,
            mechanics: exercise.resolvedMechanics
        )

        let reason: String
        if sessionMode == .recovery {
            reason = "Recovery work for \(exercise.primaryMuscles.map(\.displayName).joined(separator: ", "))."
        } else if stats?.returningFromBreak == true {
            reason = "Re-entry session — eased load after a training break"
        } else if stats?.isInDeloadWeek == true {
            reason = "Deload week — reduced volume and weight for recovery"
        } else {
            reason = "Targets \(exercise.primaryMuscles.map(\.displayName).joined(separator: ", ")) with available equipment."
        }

        let workingSets = (0..<adjustedSetCount).map { _ in
            PlannedSet(
                targetRepsMin: minReps,
                targetRepsMax: maxReps,
                targetWeightKg: plannedWeight,
                rpeTarget: rpeTarget
            )
        }
        let warmupSets: [PlannedSet]
        if sessionMode == .standard, input.userProfile.includeWarmupSets, !exercise.usesBodyweightLoading {
            warmupSets = WarmupSetPlanner.warmupSets(
                workingWeight: weight,
                workingRepsMin: minReps,
                rpeTarget: rpeTarget
            )
        } else {
            warmupSets = []
        }

        return PlannedExercise(
            exerciseId: exercise.id,
            orderIndex: orderIndex,
            targetSets: warmupSets + workingSets,
            restSeconds: restSeconds,
            intensity: intensity,
            reason: reason
        )
    }

    private func defaultWeight(
        for exercise: Exercise,
        experience: ExperienceLevel,
        bodyweightKg: Double?
    ) -> Double {
        let flat = flatDefaultWeight(for: exercise, experience: experience)
        guard let bodyweightKg, bodyweightKg > 0 else { return flat }
        let suggested = ProgressiveOverload.suggestedStartWeight(
            for: exercise,
            bodyweight: bodyweightKg,
            experience: experience
        )
        if experience == .beginner,
           suggested > flat * GenerationConstants.Session.beginnerStartWeightClampMultiplier {
            return flat
        }
        return suggested
    }

    private func flatDefaultWeight(for exercise: Exercise, experience: ExperienceLevel) -> Double {
        let isBarbell = exercise.equipment.contains(.barbell)
        switch experience {
        case .beginner:
            return isBarbell
                ? GenerationConstants.Session.flatBeginnerBarbellWeightKg
                : GenerationConstants.Session.flatBeginnerDumbbellWeightKg
        case .intermediate:
            return isBarbell
                ? GenerationConstants.Session.flatIntermediateBarbellWeightKg
                : GenerationConstants.Session.flatIntermediateDumbbellWeightKg
        case .advanced:
            return isBarbell
                ? GenerationConstants.Session.flatAdvancedBarbellWeightKg
                : GenerationConstants.Session.flatAdvancedDumbbellWeightKg
        }
    }

    private func buildRationale(input: WorkoutGenerationInput, muscles: [MuscleGroup]) -> String {
        let splitLabel = input.splitDayFocus?.displayName ?? input.userProfile.preferredSplit.displayName
        let lowRecovery = input.muscleRecovery.filter { $0.value < GenerationConstants.Recovery.readyMuscleMinRecovery }.map(\.key.displayName)
        if lowRecovery.isEmpty {
            return "Target muscles are recovered. Today's \(splitLabel) session biases \(muscles.map(\.displayName).joined(separator: ", "))."
        }
        return "\(splitLabel) rotation with recovery adjustments. Avoiding heavily fatigued areas (\(lowRecovery.joined(separator: ", ")))."
    }

    private func deloadAdjustment(
        baseSetCount: Int,
        stats: UserExerciseStats?
    ) -> (intensity: IntensityTarget, setCount: Int) {
        guard let stats, stats.isInDeloadWeek, !stats.returningFromBreak else {
            return (.moderate, baseSetCount)
        }
        let reducedSets = max(1, Int(Double(baseSetCount) * GenerationConstants.Session.deloadSetMultiplier))
        return (.light, reducedSets)
    }
}

enum WorkoutValidator {
    static func adjustedWeeklySetCap(for input: WorkoutGenerationInput) -> Int {
        GenerationConstants.Volume.adjustedWeeklySetCap(
            experience: input.experienceLevel,
            soreness: input.readiness?.soreness ?? .none
        )
    }

    static func validate(
        workout: GeneratedWorkout,
        input: WorkoutGenerationInput,
        exercises: [Exercise]
    ) -> WorkoutValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        var suggestions: [String] = []

        let isRecovery = workout.sessionMode == .recovery
        let exerciseMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        var exerciseIds = Set<String>()

        let minExercises = isRecovery
            ? GenerationConstants.RecoverySession.minExercises
            : GenerationConstants.Session.minStandardExercises
        if workout.exercises.count < minExercises {
            errors.append("Workout has fewer than \(minExercises) exercises.")
        }

        let workoutMuscles = workout.focus.isEmpty ? MuscleGroup.allCases : workout.focus
        let avgRecovery = workoutMuscles
            .map { GenerationConstants.Recovery.recovery(for: $0, in: input.muscleRecovery) }
            .reduce(0, +) / Double(workoutMuscles.count)
        let workoutIntensity = IntensityCalculator.workoutIntensity(exercises: workout.exercises, exerciseMap: exerciseMap)
        let totalSets = VolumeCalculator.totalSets(exercises: workout.exercises)
        let weeklyVolume = VolumeCalculator.weeklyVolumeEstimate(recentWorkouts: input.recentWorkouts)

        let soreness = input.readiness?.soreness ?? .none
        let volumeCap = adjustedWeeklySetCap(for: input)
        let volumeWarningThreshold = GenerationConstants.Volume.warningThreshold(
            experience: input.experienceLevel,
            soreness: soreness
        )

        validateSoreness(input: input, isRecovery: isRecovery, totalSets: totalSets, warnings: &warnings, errors: &errors, suggestions: &suggestions)
        validateGlobalRecovery(input: input, isRecovery: isRecovery, errors: &errors, warnings: &warnings, suggestions: &suggestions)
        validateWeeklyVolume(
            totalSets: totalSets,
            weeklyVolume: weeklyVolume,
            volumeCap: volumeCap,
            volumeWarningThreshold: volumeWarningThreshold,
            errors: &errors,
            warnings: &warnings,
            suggestions: &suggestions
        )

        validateIntensity(
            workoutIntensity: workoutIntensity,
            avgRecovery: avgRecovery,
            warnings: &warnings,
            suggestions: &suggestions
        )

        for planned in workout.exercises {
            if !exerciseIds.insert(planned.exerciseId).inserted {
                errors.append("Duplicate exercise: \(planned.exerciseId)")
            }

            guard let exercise = exerciseMap[planned.exerciseId] else {
                errors.append("Unknown exercise: \(planned.exerciseId)")
                continue
            }

            if GenerationConstants.violatesInjuries(exercise, injuries: input.injuries) {
                errors.append("\(exercise.name) conflicts with reported limitations.")
            }

            if !EquipmentFilter.isExerciseAvailable(exercise, availableEquipment: input.availableEquipment) {
                errors.append("\(exercise.name) requires unavailable equipment.")
            }

            validatePrescription(
                planned: planned,
                exercise: exercise,
                input: input,
                errors: &errors,
                warnings: &warnings
            )
            validateMuscleRecovery(
                exercise: exercise,
                input: input,
                isRecovery: isRecovery,
                errors: &errors,
                warnings: &warnings
            )
        }

        if workout.estimatedDurationMinutes > input.targetDurationMinutes + GenerationConstants.Validation.durationOverTargetMinutes {
            warnings.append("Workout may exceed target duration by >20 minutes.")
        }

        return WorkoutValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            suggestions: suggestions
        )
    }

    private static func validateSoreness(
        input: WorkoutGenerationInput,
        isRecovery: Bool,
        totalSets: Int,
        warnings: inout [String],
        errors: inout [String],
        suggestions: inout [String]
    ) {
        let soreness = input.readiness?.soreness ?? .none
        if soreness == .severe {
            let message = "Severe soreness reported — consider rescheduling or significantly reducing intensity."
            if isRecovery {
                warnings.append(message)
            } else {
                errors.append(message)
            }
            suggestions.append("Swap 30% of compound exercises for isolation movements and reduce volume by 40%.")
        } else if soreness == .moderate {
            warnings.append("Moderate soreness reported — consider reducing volume by 20%.")
            suggestions.append(
                "Reduce volume: aim for \(Int(Double(totalSets) * GenerationConstants.Validation.moderateSorenessVolumeReduction)) "
                    + "sets instead of \(totalSets)."
            )
        } else if soreness == .mild {
            warnings.append("Mild soreness noted — monitor intensity.")
        }
    }

    private static func validateGlobalRecovery(
        input: WorkoutGenerationInput,
        isRecovery: Bool,
        errors: inout [String],
        warnings: inout [String],
        suggestions: inout [String]
    ) {
        let minRecovery = GenerationConstants.Recovery.minimumRecovery(in: input.muscleRecovery)
        if minRecovery < GenerationConstants.Recovery.criticalFatigueThreshold {
            let message = "Critical fatigue detected (\(Int(minRecovery))% recovery). Recommend lighter session or rest day."
            if isRecovery {
                warnings.append(message)
            } else {
                errors.append(message)
            }
            suggestions.append("Reduce intensity to light/recovery work. Aim for RPE ≤ 6.")
        } else if minRecovery < GenerationConstants.Recovery.lowRecoveryWarningThreshold {
            warnings.append("Low fatigue threshold (\(Int(minRecovery))% recovery). Consider deload.")
            suggestions.append("Reduce exercise intensity or volume; consider focusing on technique and recovery.")
        }
    }

    private static func validateWeeklyVolume(
        totalSets: Int,
        weeklyVolume: Int,
        volumeCap: Int,
        volumeWarningThreshold: Int,
        errors: inout [String],
        warnings: inout [String],
        suggestions: inout [String]
    ) {
        let projectedWeeklyVolume = weeklyVolume + totalSets
        if projectedWeeklyVolume > volumeCap {
            errors.append("Projected weekly volume (\(projectedWeeklyVolume) sets) exceeds safe threshold (\(volumeCap)). Consider deload.")
        } else if projectedWeeklyVolume > volumeWarningThreshold {
            warnings.append("Weekly volume trending high (\(projectedWeeklyVolume) sets). Monitor for overtraining.")
            suggestions.append("Consider reducing volume or extending recovery between sessions.")
        }
    }

    private static func validateIntensity(
        workoutIntensity: Double,
        avgRecovery: Double,
        warnings: inout [String],
        suggestions: inout [String]
    ) {
        let adjustedIntensity = IntensityCalculator.fatigueAdjustedIntensity(
            baseIntensity: workoutIntensity,
            recoveryPercent: avgRecovery
        )
        if workoutIntensity > GenerationConstants.Validation.highIntensityThreshold
            && avgRecovery < GenerationConstants.Recovery.readyMuscleMinRecovery {
            warnings.append("High intensity workout planned with low average recovery (\(Int(avgRecovery))%). Risk of overtraining.")
            suggestions.append("Reduce intensity or defer high-intensity work. Replace heavy compounds with moderate-intensity accessory work.")
        } else if adjustedIntensity > workoutIntensity * GenerationConstants.Validation.lowRecoveryAdjustedIntensityFraction
            && avgRecovery < GenerationConstants.Recovery.lowRecoveryWarningThreshold {
            suggestions.append(
                "Estimated intensity reduced to \(String(format: "%.1f", adjustedIntensity * 100))% "
                    + "due to low recovery. Session will be lighter-than-planned."
            )
        }
    }

    private static func validatePrescription(
        planned: PlannedExercise,
        exercise: Exercise,
        input: WorkoutGenerationInput,
        errors: inout [String],
        warnings: inout [String]
    ) {
        let workingSets = planned.targetSets.filter { !$0.isWarmup }
        if workingSets.count < GenerationConstants.Validation.minSetsPerExercise
            || workingSets.count > GenerationConstants.Validation.maxSetsPerExercise {
            errors.append("Invalid set count for \(exercise.name).")
        }

        if planned.restSeconds < GenerationConstants.Validation.minRestSeconds
            || planned.restSeconds > GenerationConstants.Validation.maxRestSeconds {
            errors.append("Invalid rest period for \(exercise.name).")
        }

        let isBodyweightExercise = exercise.usesBodyweightLoading
        for set in planned.targetSets {
            if let weight = set.targetWeightKg {
                if weight < 0 || weight > GenerationConstants.Validation.maxPlannedWeightKg {
                    errors.append("Invalid weight for \(exercise.name).")
                }
                if isBodyweightExercise && weight > 0 {
                    errors.append("Bodyweight exercise \(exercise.name) should not have a loaded weight.")
                }
            }
            if set.targetRepsMin < GenerationConstants.Validation.minRepCount
                || set.targetRepsMax > GenerationConstants.Validation.maxRepCount
                || set.targetRepsMin > set.targetRepsMax {
                errors.append("Invalid rep range for \(exercise.name).")
            }
        }

        if let lastWeight = input.exerciseStats.first(where: { $0.exerciseId == planned.exerciseId })?.lastWeightKg {
            let jumpThreshold = lastWeight * GenerationConstants.Validation.weightJumpWarningMultiplier
            if planned.targetSets.contains(where: { ($0.targetWeightKg ?? 0) > jumpThreshold }) {
                warnings.append("Large weight jump for \(exercise.name) — verify planned load.")
            }
        }
    }

    private static func validateMuscleRecovery(
        exercise: Exercise,
        input: WorkoutGenerationInput,
        isRecovery: Bool,
        errors: inout [String],
        warnings: inout [String]
    ) {
        for muscle in exercise.primaryMuscles {
            let muscleRecovery = GenerationConstants.Recovery.recovery(for: muscle, in: input.muscleRecovery)
            if muscleRecovery < GenerationConstants.Recovery.criticalFatigueThreshold {
                let message = """
                \(muscle.displayName) critically fatigued \
                (<\(Int(GenerationConstants.Recovery.criticalFatigueThreshold))% recovery). \
                \(exercise.name) not recommended.
                """
                if isRecovery {
                    warnings.append(message)
                } else {
                    errors.append(message)
                }
            } else if muscleRecovery < GenerationConstants.Recovery.lowRecoveryWarningThreshold {
                warnings.append("\(muscle.displayName) recovery very low. Consider swapping \(exercise.name) for a secondary muscle focus.")
            }
        }
    }
}
