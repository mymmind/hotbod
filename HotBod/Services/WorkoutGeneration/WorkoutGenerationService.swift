// swiftlint:disable type_body_length function_body_length
import Foundation

final class RulesWorkoutGenerationService: WorkoutGenerationService, Sendable {
    private let exerciseRepo: any ExerciseRepository

    init(exerciseRepository: any ExerciseRepository = LocalExerciseRepository()) {
        self.exerciseRepo = exerciseRepository
    }

    func generate(input: WorkoutGenerationInput) async throws -> GeneratedWorkout {
        let input = Self.applyingManualReadiness(input)
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

    private static func applyingManualReadiness(_ input: WorkoutGenerationInput) -> WorkoutGenerationInput {
        guard let manual = input.readiness?.manualReadiness else { return input }
        let states = input.muscleRecovery.map { muscle, value in
            MuscleRecoveryState(
                muscleGroup: muscle,
                recoveryPercentage: value,
                lastTrainedAt: nil,
                accumulatedFatigue: 0
            )
        }
        let adjustedMap = RecoveryCalculator.recoveryMap(
            from: RecoveryCalculator.applyManualReadiness(states: states, manualReadiness: manual)
        )
        return WorkoutGenerationInput(
            userProfile: input.userProfile,
            goal: input.goal,
            experienceLevel: input.experienceLevel,
            availableEquipment: input.availableEquipment,
            targetDurationMinutes: input.targetDurationMinutes,
            preferredMuscleGroups: input.preferredMuscleGroups,
            avoidedMuscleGroups: input.avoidedMuscleGroups,
            injuries: input.injuries,
            recentWorkouts: input.recentWorkouts,
            muscleRecovery: adjustedMap,
            exerciseStats: input.exerciseStats,
            userPreferences: input.userPreferences,
            readiness: input.readiness,
            splitDayFocus: input.splitDayFocus,
            forceRecoverySession: input.forceRecoverySession
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
            (avoidedOverride || !exercise.primaryMuscles.contains(where: { input.avoidedMuscleGroups.contains($0) })) &&
            !shouldExcludeCardio(exercise, input: input)
        }
    }

    private func shouldExcludeCardio(_ exercise: Exercise, input: WorkoutGenerationInput) -> Bool {
        guard exercise.movementPattern == .cardio else { return false }
        let strengthGoals: Set<TrainingGoal> = [.buildMuscle, .gainStrength]
        guard strengthGoals.contains(input.goal) else { return false }
        if input.userProfile.includeConditioning {
            return input.userProfile.cardioBlockPlacement != .none
        }
        return true
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
                variability: input.userPreferences.exerciseVariability,
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
                variability: input.userPreferences.exerciseVariability,
                favoriteIds: favoriteIds,
                relaxDifficultyPenalty: filterOptions.relaxDifficultyPenalty
            )

        let exerciseMap = ExerciseCatalog.indexedById(allExercises)
        let completedVolume = MuscleVolumePlanner.completedHardSets(
            stats: input.exerciseStats,
            exerciseMap: exerciseMap
        )

        let setOverrides: [Int?]
        if sessionMode == .standard {
            let remaining = MuscleVolumePlanner.remainingBudget(
                targetMuscles: targetMuscles,
                completed: completedVolume,
                experience: input.experienceLevel,
                goal: input.goal,
                soreness: input.readiness?.soreness ?? .none,
                preferredMuscles: input.preferredMuscleGroups
            )
            let baseCounts = selection.exercises.map { exercise in
                ExercisePrescriptionOverrides.effectiveSetCount(
                    exerciseId: exercise.id,
                    experience: input.experienceLevel,
                    pattern: exercise.movementPattern
                )
            }
            setOverrides = MuscleVolumePlanner.allocateSessionSetCounts(
                exercises: selection.exercises,
                baseSetCounts: baseCounts,
                remaining: remaining
            ).enumerated().map { index, count in
                let exercise = selection.exercises[index]
                let lowPrep = exercise.primaryMuscles.contains {
                    GenerationConstants.Recovery.recovery(for: $0, in: input.muscleRecovery)
                        < GenerationConstants.Recovery.softShrinkPreparednessThreshold
                }
                if lowPrep {
                    return max(1, Int((Double(count) * GenerationConstants.Recovery.softShrinkSetMultiplier).rounded()))
                }
                return count
            }.map { Optional($0) }
        } else {
            setOverrides = Array(repeating: nil, count: selection.exercises.count)
        }

        var planned = selection.exercises.enumerated().map { index, exercise in
            planExercise(
                exercise,
                orderIndex: index,
                input: input,
                sessionMode: sessionMode,
                workingSetCountOverride: setOverrides[index],
                completedMuscleVolume: completedVolume
            )
        }

        if sessionMode == .standard {
            WorkoutGenerationAlgorithms.trimToDuration(
                planned: &planned,
                scores: selection.scores,
                targetMuscles: targetMuscles,
                exerciseMap: exerciseMap,
                targetDurationMinutes: input.targetDurationMinutes
            )
            ExerciseGroupPlanner.applyGrouping(
                to: &planned,
                preference: input.userProfile.preferredExerciseGrouping,
                exerciseMap: exerciseMap
            )
            SessionStructurePlanner.applyCardioBlock(
                to: &planned,
                placement: input.userProfile.cardioBlockPlacement,
                exercises: allExercises,
                availableEquipment: input.availableEquipment,
                includeConditioning: input.userProfile.includeConditioning
                    || !([TrainingGoal.buildMuscle, .gainStrength].contains(input.goal))
            )
            if input.userProfile.includeCoreFinisher {
                CoreFinisherPlanner.appendCoreFinisher(
                    to: &planned,
                    exercises: allExercises,
                    availableEquipment: input.availableEquipment,
                    experience: input.experienceLevel,
                    splitDayFocus: input.splitDayFocus,
                    exerciseStats: input.exerciseStats
                )
            }
            if input.userProfile.includeCooldown {
                SessionStructurePlanner.appendCooldownSets(to: &planned, exerciseMap: exerciseMap)
            }
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
        let selectionRationale = WorkoutSelectionRationale.build(
            input: input,
            muscles: targetMuscles,
            selectedExercises: selection.exercises,
            sessionMode: sessionMode,
            filterOptions: WorkoutSelectionFilterContext(
                includeAvoided: filterOptions.includeAvoided,
                relaxDifficultyPenalty: filterOptions.relaxDifficultyPenalty
            )
        )

        var workout = GeneratedWorkout(
            id: UUID(),
            title: title,
            estimatedDurationMinutes: duration,
            focus: targetMuscles,
            exercises: planned,
            rationale: rationale,
            selectionRationale: selectionRationale,
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
        return workout
    }

    func validate(workout: GeneratedWorkout, input: WorkoutGenerationInput) -> WorkoutValidationResult {
        WorkoutValidator.validate(workout: workout, input: input, exercises: (try? ExerciseSeedLoader.load()) ?? [])
    }

    // MARK: - Session mode

    private func shouldUseRecoveryMode(input: WorkoutGenerationInput) -> Bool {
        if input.forceRecoverySession { return true }
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
        guard let sleep = GenerationConstants.Recovery.normalizeSleepScore(readiness?.sleepScore) else { return }
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
        variability: ExerciseVariabilityLevel = .balanced,
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
            variability: variability,
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
        variability: ExerciseVariabilityLevel,
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
            variability: variability,
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
        sessionMode: SessionMode,
        workingSetCountOverride: Int? = nil,
        completedMuscleVolume: [MuscleGroup: Double] = [:]
    ) -> PlannedExercise {
        let stats = input.exerciseStats.first { $0.exerciseId == exercise.id }
        let prescription = exercise.resolvedPrescriptionType
        let repRange = ExercisePrescriptionOverrides.effectiveRepRange(
            exerciseId: exercise.id,
            stats: stats,
            goal: input.goal,
            experience: input.experienceLevel
        )
        let minReps = repRange.min
        let maxReps = repRange.max
        let setCount = workingSetCountOverride ?? ExercisePrescriptionOverrides.effectiveSetCount(
            exerciseId: exercise.id,
            experience: input.experienceLevel,
            pattern: exercise.movementPattern
        )

        let soreness = input.readiness?.soreness ?? .none
        let muscleCompletion = MuscleVolumePlanner.primaryCompletionFraction(
            exercise: exercise,
            completed: completedMuscleVolume,
            experience: input.experienceLevel,
            goal: input.goal,
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
                muscleVolumeCompletion: muscleCompletion,
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

        weight = GenerationConstants.Weight.roundToAvailable(
            weight,
            equipment: exercise.equipment,
            ceilings: input.userProfile.maxAvailableWeightKg
        )
        let loadMode = exercise.resolvedLoadTrackingMode
        let canPlanExternalLoad: Bool = switch loadMode {
        case .none:
            false
        case .optional:
            // Optional exercises start planning with external load once the user has logged it before.
            stats?.planningWeightKg != nil
        case .supported, .required:
            true
        }
        let plannedWeight: Double? = canPlanExternalLoad ? weight : nil

        var (intensity, adjustedSetCount) = deloadAdjustment(baseSetCount: setCount, stats: stats)
        var rpeTarget = ExercisePrescriptionOverrides.effectiveRPETarget(
            exerciseId: exercise.id,
            fallback: EffortPolicy.targetRPE(
                for: EffortPolicy.context(
                    EffortPolicy.SessionSignals(
                        goal: input.goal,
                        experience: input.experienceLevel,
                        mechanics: exercise.resolvedMechanics,
                        sessionMode: sessionMode,
                        isDeload: stats?.isInDeloadWeek == true,
                        returningFromBreak: stats?.returningFromBreak == true,
                        sleepScore: input.readiness?.sleepScore
                    )
                )
            )
        )

        if stats?.returningFromBreak == true {
            adjustedSetCount = setCount
            intensity = .moderate
            rpeTarget = GenerationConstants.Deload.reEntryRPETarget
        }

        if sessionMode == .recovery {
            adjustedSetCount = max(1, adjustedSetCount - 1)
            intensity = .light
        } else if let sleep = GenerationConstants.Recovery.normalizeSleepScore(input.readiness?.sleepScore),
                  sleep < GenerationConstants.Recovery.poorSleepScoreThreshold,
                  exercise.resolvedMechanics == .compound {
            adjustedSetCount = max(1, adjustedSetCount - 1)
        }

        let restSeconds = ExercisePrescriptionOverrides.effectiveRestSeconds(
            exerciseId: exercise.id,
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
            plannedWorkingSet(
                prescription: prescription,
                exercise: exercise,
                minReps: minReps,
                maxReps: maxReps,
                plannedWeight: plannedWeight,
                rpeTarget: rpeTarget
            )
        }
        var mutableWorkingSets = workingSets
        if MaxEffortPlanner.shouldScheduleMaxEffort(stats: stats, sessionMode: sessionMode) {
            MaxEffortPlanner.markMaxEffortSet(in: &mutableWorkingSets)
        }
        let warmupSets: [PlannedSet]
        if sessionMode == .standard,
           input.userProfile.includeWarmupSets,
           canPlanExternalLoad,
           prescription == .reps {
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
            targetSets: warmupSets + mutableWorkingSets,
            restSeconds: restSeconds,
            intensity: intensity,
            reason: reason
        )
    }

    private func plannedWorkingSet(
        prescription: PrescriptionType,
        exercise: Exercise,
        minReps: Int,
        maxReps: Int,
        plannedWeight: Double?,
        rpeTarget: Double
    ) -> PlannedSet {
        switch prescription {
        case .time:
            let seconds = ExerciseMetadataResolver.defaultDurationSeconds(for: exercise)
            return PlannedSet(
                targetRepsMin: 0,
                targetRepsMax: 0,
                targetWeightKg: plannedWeight,
                rpeTarget: rpeTarget,
                targetDurationSeconds: seconds
            )
        case .distance:
            let meters = ExerciseMetadataResolver.defaultDistanceMeters(for: exercise)
            return PlannedSet(
                targetRepsMin: 0,
                targetRepsMax: 0,
                targetWeightKg: plannedWeight,
                rpeTarget: rpeTarget,
                targetDistanceMeters: meters
            )
        case .distanceOrTime:
            let meters = ExerciseMetadataResolver.defaultDistanceMeters(for: exercise)
            return PlannedSet(
                targetRepsMin: 0,
                targetRepsMax: 0,
                targetWeightKg: plannedWeight,
                rpeTarget: rpeTarget,
                targetDistanceMeters: meters
            )
        case .reps:
            return PlannedSet(
                targetRepsMin: minReps,
                targetRepsMax: maxReps,
                targetWeightKg: plannedWeight,
                rpeTarget: rpeTarget
            )
        }
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
