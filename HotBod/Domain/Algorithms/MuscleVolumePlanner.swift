import Foundation

/// Schoenfeld-style per-muscle hard-set volume planning.
struct SessionSetAllocation: Equatable {
    var setCounts: [Int]
    var notes: [String]
}

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
        preferredMuscles: [MuscleGroup] = [],
        physiquePreferredMuscles: [MuscleGroup] = []
    ) -> [MuscleGroup: Double] {
        let landing = weeklyLanding(experience: experience, goal: goal, soreness: soreness)
        var remaining: [MuscleGroup: Double] = [:]
        for muscle in targetMuscles {
            let boost: Double
            if physiquePreferredMuscles.contains(muscle) {
                boost = GenerationConstants.Volume.physiquePreferredBoost
            } else if preferredMuscles.contains(muscle) {
                boost = GenerationConstants.Volume.profilePreferredBoost
            } else {
                boost = 0
            }
            let target = landing + boost
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

    /// Allocates working-set counts from the per-session share of the weekly landing.
    /// An exercise is capped by the target muscle it was chosen for. A count of 0 means drop it.
    static func allocateSessionSetCounts(
        exercises: [Exercise],
        baseSetCounts: [Int],
        remaining: [MuscleGroup: Double],
        weeklyLanding: Double? = nil,
        exposuresPerWeek: Int = 1,
        targetMuscles: [MuscleGroup] = [],
        softCeiling: Double = Double(GenerationConstants.Volume.softCeilingSetsPerMuscle)
    ) -> SessionSetAllocation {
        precondition(exercises.count == baseSetCounts.count)
        var allowance = remaining
        if let weeklyLanding {
            let perSession = weeklyLanding / Double(max(1, exposuresPerWeek))
            let muscles = Set(remaining.keys).union(targetMuscles)
            for muscle in muscles {
                allowance[muscle] = min(remaining[muscle] ?? 0, perSession)
            }
        }

        func coveredMuscle(for exercise: Exercise, using budget: [MuscleGroup: Double]) -> MuscleGroup? {
            let pool = targetMuscles.isEmpty
                ? exercise.primaryMuscles
                : exercise.primaryMuscles.filter { targetMuscles.contains($0) }
            let candidates = pool.isEmpty ? exercise.primaryMuscles : pool
            return candidates.max { lhs, rhs in
                (budget[lhs] ?? 0) < (budget[rhs] ?? 0)
            }
        }

        let covered = exercises.map { coveredMuscle(for: $0, using: allowance) }
        var allocated = Array(repeating: 0, count: exercises.count)
        var dropped: [MuscleGroup] = []
        var reduced: [MuscleGroup] = []

        for (index, exercise) in exercises.enumerated() {
            let base = max(1, baseSetCounts[index])
            guard let muscle = covered[index] else {
                allocated[index] = base
                continue
            }
            let left = allowance[muscle] ?? 0
            let later = covered.suffix(from: index + 1).filter { $0 == muscle }.count
            let share = left / Double(later + 1)
            let ceilingShare = softCeiling / Double(later + 1)
            let sets: Int
            if left < 2 {
                sets = 0
            } else if share < 2 {
                sets = min(base, Int(left.rounded()))
            } else {
                sets = min(base, Int(share.rounded()), Int(ceilingShare.rounded()))
            }
            guard sets >= 2 else {
                allocated[index] = 0
                dropped.append(muscle)
                continue
            }
            if sets < base {
                reduced.append(muscle)
            }
            allocated[index] = sets
            for (credited, credit) in hardSetCredits(for: exercise) {
                allowance[credited] = max(0, (allowance[credited] ?? 0) - Double(sets) * credit)
            }
        }

        return SessionSetAllocation(
            setCounts: allocated,
            notes: volumeNotes(dropped: dropped, reduced: reduced)
        )
    }

    private static func volumeNotes(dropped: [MuscleGroup], reduced: [MuscleGroup]) -> [String] {
        var notes: [String] = []
        var seen = Set<MuscleGroup>()
        for muscle in dropped where seen.insert(muscle).inserted {
            notes.append("\(muscle.displayName) is full for this week, so that work was left out.")
        }
        for muscle in reduced where !dropped.contains(muscle) && seen.insert(muscle).inserted {
            notes.append("\(muscle.displayName) volume is full, so this session uses fewer sets.")
        }
        return notes
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
