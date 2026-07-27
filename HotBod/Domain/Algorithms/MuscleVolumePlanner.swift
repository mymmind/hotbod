import Foundation

/// Schoenfeld-style per-muscle hard-set volume planning.
enum MuscleVolumePlanner {
    /// Credits one working set toward each muscle the exercise trains.
    static func hardSetCredits(for exercise: Exercise) -> [MuscleGroup: Double] {
        var credits: [MuscleGroup: Double] = [:]
        for muscle in exercise.primaryMuscles {
            credits[muscle, default: 0] += GenerationConstants.Volume.primaryHardSetCredit
        }
        for muscle in exercise.secondaryMuscles {
            credits[muscle, default: 0] += GenerationConstants.Volume.secondaryHardSetCredit
        }
        return credits
    }

    static func weeklyLanding(
        experience: ExperienceLevel,
        goal: TrainingGoal,
        soreness: SorenessLevel = .none
    ) -> Double {
        let base = Double(GenerationConstants.Volume.weeklyLandingSets(experience: experience, goal: goal))
        return base * GenerationConstants.Volume.sorenessReductionFactor(soreness)
    }

    /// Rolling 7×24h completed hard-set credits per muscle from exercise stats.
    static func completedHardSets(
        stats: [UserExerciseStats],
        exerciseMap: [String: Exercise],
        endingAt now: Date = Date()
    ) -> [MuscleGroup: Double] {
        var totals: [MuscleGroup: Double] = [:]
        for entry in stats {
            guard let exercise = exerciseMap[entry.exerciseId] else { continue }
            let setCount = VolumeTracker.rollingSetCount(from: entry.recentSets, endingAt: now)
            guard setCount > 0 else { continue }
            let credits = hardSetCredits(for: exercise)
            for (muscle, credit) in credits {
                totals[muscle, default: 0] += Double(setCount) * credit
            }
        }
        return totals
    }

    /// Remaining weekly hard-set budget for each muscle (floored at 0).
    static func remainingBudget(
        targetMuscles: [MuscleGroup],
        completed: [MuscleGroup: Double],
        experience: ExperienceLevel,
        goal: TrainingGoal,
        soreness: SorenessLevel = .none,
        preferredMuscles: [MuscleGroup] = []
    ) -> [MuscleGroup: Double] {
        let landing = weeklyLanding(experience: experience, goal: goal, soreness: soreness)
        let preferredBoost = preferredMuscles.isEmpty ? 0.0 : 2.0
        var remaining: [MuscleGroup: Double] = [:]
        for muscle in targetMuscles {
            let target = landing + (preferredMuscles.contains(muscle) ? preferredBoost : 0)
            let done = completed[muscle] ?? 0
            remaining[muscle] = max(0, target - done)
        }
        return remaining
    }

    /// Average completion fraction (done / landing) across an exercise's primary muscles.
    static func primaryCompletionFraction(
        exercise: Exercise,
        completed: [MuscleGroup: Double],
        experience: ExperienceLevel,
        goal: TrainingGoal,
        soreness: SorenessLevel = .none
    ) -> Double {
        let landing = weeklyLanding(experience: experience, goal: goal, soreness: soreness)
        guard landing > 0, !exercise.primaryMuscles.isEmpty else { return 0 }
        let fractions = exercise.primaryMuscles.map { muscle in
            (completed[muscle] ?? 0) / landing
        }
        return fractions.reduce(0, +) / Double(fractions.count)
    }

    /// Allocates working-set counts so session credits stay near remaining weekly budgets.
    static func allocateSessionSetCounts(
        exercises: [Exercise],
        baseSetCounts: [Int],
        remaining: [MuscleGroup: Double],
        softCeiling: Double = Double(GenerationConstants.Volume.softCeilingSetsPerMuscle)
    ) -> [Int] {
        precondition(exercises.count == baseSetCounts.count)
        var leftover = remaining
        var allocated = Array(repeating: 1, count: exercises.count)

        for (index, exercise) in exercises.enumerated() {
            let base = max(1, baseSetCounts[index])
            let primaries = exercise.primaryMuscles
            guard let limiting = primaries.map({ leftover[$0] ?? 0 }).min() else {
                allocated[index] = base
                continue
            }

            let coveringCount = max(1, exercises.suffix(from: index).filter { candidate in
                !Set(candidate.primaryMuscles).isDisjoint(with: Set(primaries))
            }.count)

            let budgetShare = limiting / Double(coveringCount)
            let ceilingShare = softCeiling / Double(max(1, coveringCount))
            // Floor at 1 set so selected exercises remain loggable; soft-shrink +
            // validator warnings absorb weekly overshoot when budget is already spent.
            let desired = min(Double(base), max(1, budgetShare), ceilingShare)
            let sets = max(1, Int(desired.rounded()))
            allocated[index] = sets

            let credits = hardSetCredits(for: exercise)
            for (muscle, credit) in credits {
                leftover[muscle] = max(0, (leftover[muscle] ?? 0) - Double(sets) * credit)
            }
        }
        return allocated
    }

    /// Planned session hard-set credits by muscle.
    static func plannedHardSets(
        planned: [PlannedExercise],
        exerciseMap: [String: Exercise]
    ) -> [MuscleGroup: Double] {
        var totals: [MuscleGroup: Double] = [:]
        for item in planned {
            guard let exercise = exerciseMap[item.exerciseId] else { continue }
            let working = item.targetSets.filter { !$0.isWarmup && !$0.isCooldown }.count
            guard working > 0 else { continue }
            for (muscle, credit) in hardSetCredits(for: exercise) {
                totals[muscle, default: 0] += Double(working) * credit
            }
        }
        return totals
    }
}
