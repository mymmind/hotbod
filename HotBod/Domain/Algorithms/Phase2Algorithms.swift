import Foundation

struct WorkoutGenerationOptions: Hashable {
    var targetDurationMinutes: Int?
    var soreness: SorenessLevel?
    var excludeExerciseIds: [String] = []
    var preferVariation: Bool = false
}

enum ExerciseSubstitution {
    /// Returns ranked substitute exercises for a given exercise.
    static func candidates(
        for exerciseId: String,
        from exercises: [Exercise],
        availableEquipment: [Equipment],
        injuries: [BodyLimitation],
        excludeIds: Set<String> = []
    ) -> [Exercise] {
        ExerciseCatalog.substitutes(
            for: exerciseId,
            from: exercises,
            availableEquipment: availableEquipment,
            injuries: injuries,
            excludeIds: excludeIds
        )
    }

    static func isEquipmentAvailable(_ exercise: Exercise, available: [Equipment]) -> Bool {
        EquipmentFilter.isExerciseAvailable(exercise, availableEquipment: available)
    }

    static func violatesInjuries(_ exercise: Exercise, injuries: [BodyLimitation]) -> Bool {
        GenerationConstants.violatesInjuries(exercise, injuries: injuries)
    }

    static func scoreSubstitute(_ source: Exercise, _ candidate: Exercise) -> Double {
        var score = 0.0
        score += Double(Set(source.primaryMuscles).intersection(Set(candidate.primaryMuscles)).count) * 10
        score += source.movementPattern == candidate.movementPattern ? 5 : 0
        score += source.difficulty == candidate.difficulty ? 2 : 0
        return score
    }
}

enum ProteinComplianceCalculator {
    static func summary(entries: [ProteinEntry], goalGrams: Double, asOf date: Date = Date()) -> ProteinSummary {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: date)
        let todayEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let todayGrams = todayEntries.reduce(0) { $0 + $1.proteinGrams }

        var streak = 0
        var checkDate = todayStart
        while true {
            let dayEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: checkDate) }
            let dayTotal = dayEntries.reduce(0) { $0 + $1.proteinGrams }
            if dayTotal >= goalGrams * 0.9 {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }

        return ProteinSummary(todayGrams: todayGrams, goalGrams: goalGrams, streakDays: streak)
    }

    static func dailyTotals(entries: [ProteinEntry], days: Int = 7, goalGrams: Double) -> [(day: String, grams: Double, hitGoal: Bool)] {
        let calendar = Calendar.current
        return (0..<days).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: Date())!
            let dayEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
            let grams = dayEntries.reduce(0) { $0 + $1.proteinGrams }
            return (date.formatted(.dateTime.weekday(.abbreviated)), grams, grams >= goalGrams * 0.9)
        }
    }

    static func weeklyCompliancePercent(entries: [ProteinEntry], goalGrams: Double, days: Int = 7) -> Double {
        let totals = dailyTotals(entries: entries, days: days, goalGrams: goalGrams)
        guard !totals.isEmpty else { return 0 }
        let hits = totals.filter(\.hitGoal).count
        return Double(hits) / Double(totals.count) * 100
    }
}

enum StrengthHistory {
    struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let e1rm: Double
    }

    static func e1rmTrend(for exerciseId: String, stats: [UserExerciseStats]) -> [DataPoint] {
        guard let stat = stats.first(where: { $0.exerciseId == exerciseId }) else { return [] }
        return stat.recentSets.compactMap { set in
            guard let weight = set.weightKg, set.reps > 0 else { return nil }
            return DataPoint(date: set.completedAt, e1rm: ProgressiveOverload.estimateOneRepMax(weight: weight, reps: set.reps))
        }
    }

    static func topLifts(stats: [UserExerciseStats], exercises: [Exercise], limit: Int = 3) -> [(exercise: Exercise, e1rm: Double)] {
        let exerciseMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        return stats
            .compactMap { stat -> (Exercise, Double)? in
                guard let e1rm = stat.estimatedOneRepMax, let exercise = exerciseMap[stat.exerciseId] else { return nil }
                return (exercise, e1rm)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { ($0.0, $0.1) }
    }
}

// MARK: - Deload Detection

enum DeloadDetector {
    struct DeloadAnalysis {
        let isDeloadRecommended: Bool
        let reason: String
        let severity: DeloadSeverity
        let suggestsReturningFromBreak: Bool
    }

    enum DeloadSeverity: String {
        case none, mild, moderate, severe
    }

    /// Analyzes exercise stats to determine if deload is needed
    /// Returns analysis and recommendation
    static func analyzeDeloadNeed(
        stats: UserExerciseStats,
        volumeHistory: [Int],
        consecutiveWeeks: Int = 3,
        now: Date = Date()
    ) -> DeloadAnalysis {
        if !stats.isInDeloadSuppressionWindow(at: now) {
            let currentWindowSets = VolumeTracker.rollingSetCount(from: stats.recentSets, endingAt: now)
            let previousWindowSets = VolumeTracker.rollingSetCountInPreviousWindow(from: stats.recentSets, endingAt: now)
            if previousWindowSets >= GenerationConstants.Deload.minPreviousWindowSets {
                if currentWindowSets < GenerationConstants.Deload.minCurrentWindowSetsForDrop {
                    return DeloadAnalysis(
                        isDeloadRecommended: false,
                        reason: "Low volume after a break — re-entry ramp recommended",
                        severity: .none,
                        suggestsReturningFromBreak: true
                    )
                }
                let volumeDrop = 1.0 - Double(currentWindowSets) / Double(previousWindowSets)
                if volumeDrop > GenerationConstants.Deload.volumeDropThreshold {
                    return DeloadAnalysis(
                        isDeloadRecommended: true,
                        reason: "Volume dropped \(Int(volumeDrop * 100))% over the trailing 7-day window — deload in progress",
                        severity: .severe,
                        suggestsReturningFromBreak: false
                    )
                }
            }
        }

        // Check for 3+ consecutive weeks of 15%+ volume increase
        if consecutiveWeeks >= 3 {
            let recentVolumes = Array(volumeHistory.suffix(3))
            if recentVolumes.count == 3 {
                let inc1 = Double(recentVolumes[1]) / Double(max(1, recentVolumes[0])) - 1.0
                let inc2 = Double(recentVolumes[2]) / Double(max(1, recentVolumes[1])) - 1.0
                if inc1 > 0.15 && inc2 > 0.15 {
                    return DeloadAnalysis(
                        isDeloadRecommended: true,
                        reason: "3 consecutive weeks of 15%+ volume increase — suggest deload",
                        severity: .moderate,
                        suggestsReturningFromBreak: false
                    )
                }
            }
        }

        return DeloadAnalysis(
            isDeloadRecommended: false,
            reason: "Volume patterns nominal",
            severity: .none,
            suggestsReturningFromBreak: false
        )
    }

    /// Updates deload state based on volume history
    static func updateDeloadState(stats: inout UserExerciseStats, now: Date = Date()) {
        let analysis = analyzeDeloadNeed(
            stats: stats,
            volumeHistory: stats.weeklyVolume,
            consecutiveWeeks: stats.consecutiveHighVolumeWeeks,
            now: now
        )

        if analysis.suggestsReturningFromBreak {
            stats.returningFromBreak = true
            stats.consecutiveHighVolumeWeeks = 0
            return
        }

        if analysis.isDeloadRecommended {
            if stats.deloadStartedAt == nil || !stats.isInDeloadWeek {
                stats.deloadStartedAt = now
            }
            stats.consecutiveHighVolumeWeeks = 0
        }
    }
}

// MARK: - Volume Cap Calculator

enum VolumeCapCalculator {
    static func baseWeeklySetCap(experience: ExperienceLevel) -> Int {
        GenerationConstants.Volume.baseWeeklySetCap(experience: experience)
    }

    static func adjustedWeeklySetCap(
        experience: ExperienceLevel,
        soreness: SorenessLevel
    ) -> Int {
        GenerationConstants.Volume.adjustedWeeklySetCap(experience: experience, soreness: soreness)
    }

    /// Calculates recommended weekly volume for an exercise
    /// Accounts for muscle group priority and recent history
    static func recommendedWeeklyReps(
        exerciseId: String,
        stats: UserExerciseStats,
        primaryMuscles: [MuscleGroup],
        targetRepsMin: Int,
        targetRepsMax: Int
    ) -> Int {
        let avgReps = (targetRepsMin + targetRepsMax) / 2
        let recentAvgVolume = stats.weeklyVolume.isEmpty ? 0 : stats.weeklyVolume.reduce(0, +) / stats.weeklyVolume.count

        // If recent volume is low, gradually increase
        if recentAvgVolume < 50 {
            return min(recentAvgVolume + 20, avgReps * 6) // Target 6 sets per week as base
        }

        // If stable, maintain
        if stats.volumeTrend == .stable {
            return recentAvgVolume
        }

        // If increasing, continue but cap
        if stats.volumeTrend == .increasing {
            return min(recentAvgVolume + 10, avgReps * 8)
        }

        // If decreasing, restore
        return min(recentAvgVolume + 15, avgReps * 7)
    }

    /// Calculates completion percentage based on actual vs. recommended volume
    static func weeklyVolumeCompletionPercent(
        actual: Int,
        recommended: Int
    ) -> Double {
        guard recommended > 0 else { return 100.0 }
        return min(100.0, Double(actual) / Double(recommended) * 100.0)
    }
}
