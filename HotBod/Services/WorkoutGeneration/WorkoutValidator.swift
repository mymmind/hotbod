import Foundation

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
        let exerciseMap = ExerciseCatalog.indexedById(exercises)
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
        validateMuscleVolumeLandings(
            workout: workout,
            input: input,
            exerciseMap: exerciseMap,
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
        // Global set caps are a soft systemic guardrail — per-muscle landings own programming.
        let projectedWeeklyVolume = weeklyVolume + totalSets
        if projectedWeeklyVolume > volumeCap {
            warnings.append(
                "Projected weekly volume (\(projectedWeeklyVolume) sets) exceeds systemic guardrail (\(volumeCap)). Consider deload."
            )
            suggestions.append("Reduce total weekly sets or schedule a lighter week.")
        } else if projectedWeeklyVolume > volumeWarningThreshold {
            warnings.append("Weekly volume trending high (\(projectedWeeklyVolume) sets). Monitor for overtraining.")
            suggestions.append("Consider reducing volume or extending recovery between sessions.")
        }
    }

    private static func validateMuscleVolumeLandings(
        workout: GeneratedWorkout,
        input: WorkoutGenerationInput,
        exerciseMap: [String: Exercise],
        warnings: inout [String],
        suggestions: inout [String]
    ) {
        guard workout.sessionMode != .recovery else { return }
        let landing = MuscleVolumePlanner.weeklyLanding(
            experience: input.experienceLevel,
            goal: input.goal,
            soreness: input.readiness?.soreness ?? .none
        )
        let completed = MuscleVolumePlanner.completedHardSets(
            stats: input.exerciseStats,
            exerciseMap: exerciseMap
        )
        let planned = MuscleVolumePlanner.plannedHardSets(
            planned: workout.exercises,
            exerciseMap: exerciseMap
        )
        let softCeiling = Double(GenerationConstants.Volume.softCeilingSetsPerMuscle)
        let focus = workout.focus.isEmpty ? Array(planned.keys) : workout.focus

        for muscle in focus {
            let projected = (completed[muscle] ?? 0) + (planned[muscle] ?? 0)
            if projected > softCeiling {
                warnings.append(
                    "\(muscle.displayName) projected at \(Int(projected.rounded())) hard sets this week (soft ceiling \(Int(softCeiling)))."
                )
                suggestions.append("Trim accessory volume for \(muscle.displayName.lowercased()).")
            } else if projected > landing * 1.25 {
                warnings.append(
                    "\(muscle.displayName) weekly volume trending high (\(Int(projected.rounded())) / \(Int(landing.rounded())) target sets)."
                )
            }
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

        let loadMode = exercise.resolvedLoadTrackingMode
        let stats = input.exerciseStats.first { $0.exerciseId == planned.exerciseId }
        let canPlanExternalLoad: Bool = switch loadMode {
        case .none:
            false
        case .optional:
            stats?.planningWeightKg != nil
        case .supported, .required:
            true
        }
        let prescription = exercise.resolvedPrescriptionType
        for set in planned.targetSets {
            if let weight = set.targetWeightKg {
                if weight < 0 || weight > GenerationConstants.Validation.maxPlannedWeightKg {
                    errors.append("Invalid weight for \(exercise.name).")
                }
                if !canPlanExternalLoad && weight > 0 {
                    errors.append("Exercise \(exercise.name) should not have an external loaded weight for loadTrackingMode \(loadMode).")
                }
            }
            switch prescription {
            case .reps:
                if set.targetRepsMin < GenerationConstants.Validation.minRepCount
                    || set.targetRepsMax > GenerationConstants.Validation.maxRepCount
                    || set.targetRepsMin > set.targetRepsMax {
                    errors.append("Invalid rep range for \(exercise.name).")
                }
            case .time:
                if (set.targetDurationSeconds ?? 0) <= 0 {
                    errors.append("Invalid hold duration for \(exercise.name).")
                }
            case .distance, .distanceOrTime:
                if (set.targetDistanceMeters ?? 0) <= 0 {
                    errors.append("Invalid distance for \(exercise.name).")
                }
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
