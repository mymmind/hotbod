import Foundation

/// Role-aware RPE / proximity-to-failure targets (Schoenfeld effort guidelines).
enum EffortPolicy {
    enum Context: Equatable {
        case hypertrophyWorking
        case strengthCompound
        case isolationFinisher
        case beginner
        case deload
        case recovery
        case poorSleep
        case returningFromBreak
    }

    struct SessionSignals: Equatable {
        var goal: TrainingGoal
        var experience: ExperienceLevel
        var mechanics: MechanicsType?
        var sessionMode: SessionMode
        var isDeload: Bool
        var returningFromBreak: Bool
        var sleepScore: Double?
    }

    static func context(_ signals: SessionSignals) -> Context {
        if signals.sessionMode == .recovery { return .recovery }
        if signals.isDeload { return .deload }
        if signals.returningFromBreak { return .returningFromBreak }
        if let sleep = GenerationConstants.Recovery.normalizeSleepScore(signals.sleepScore),
           sleep < GenerationConstants.Recovery.poorSleepScoreThreshold {
            return .poorSleep
        }
        if signals.experience == .beginner { return .beginner }
        if signals.goal == .gainStrength, signals.mechanics == .compound { return .strengthCompound }
        if signals.mechanics == .isolation { return .isolationFinisher }
        return .hypertrophyWorking
    }

    static func targetRPE(for context: Context) -> Double {
        switch context {
        case .recovery: GenerationConstants.RecoverySession.rpeTarget
        case .deload: GenerationConstants.Session.deloadRpeTarget
        case .returningFromBreak: GenerationConstants.Deload.reEntryRPETarget
        case .poorSleep: GenerationConstants.Session.poorSleepMaxRpe
        case .beginner: GenerationConstants.Session.beginnerRpeTarget
        case .strengthCompound: 7.5
        case .isolationFinisher: 9.0
        case .hypertrophyWorking: GenerationConstants.Session.standardRpeTarget
        }
    }
}

/// Goal-aware load/rep progression and stall detection.
enum ProgressionPolicy {
    static let stallSessionThreshold = 3
    /// Sets farther apart than this are treated as separate sessions.
    static let sessionGapSeconds: TimeInterval = 3 * 60 * 60

    enum Action: Equatable {
        case increaseLoad
        case holdLoadIncreaseReps
        case hold
        case reduceLoad
        case preferVariation
    }

    static func action(
        goal: TrainingGoal,
        hitTopOfRepRange: Bool,
        missedMinimumReps: Bool,
        stalledSessions: Int
    ) -> Action {
        if stalledSessions >= stallSessionThreshold {
            return .preferVariation
        }
        if missedMinimumReps {
            return .reduceLoad
        }
        switch goal {
        case .gainStrength:
            return hitTopOfRepRange ? .increaseLoad : .hold
        case .loseFat:
            return hitTopOfRepRange ? .holdLoadIncreaseReps : .hold
        case .buildMuscle, .generalFitness, .athleticPerformance, .hybridAthlete:
            return hitTopOfRepRange ? .increaseLoad : .holdLoadIncreaseReps
        }
    }

    /// Volume score per session (sets clustered by completion time).
    static func sessionVolumeScores(from sets: [CompletedSet]) -> [Double] {
        let working = sets
            .filter { !$0.isWarmup && !$0.isCooldown }
            .sorted { $0.completedAt < $1.completedAt }
        guard let first = working.first else { return [] }

        var scores: [Double] = []
        var current = volumeScore(first)
        var lastAt = first.completedAt
        for set in working.dropFirst() {
            if set.completedAt.timeIntervalSince(lastAt) > sessionGapSeconds {
                scores.append(current)
                current = 0
            }
            current += volumeScore(set)
            lastAt = set.completedAt
        }
        scores.append(current)
        return scores
    }

    static func stalledSessionCount(stats: UserExerciseStats) -> Int {
        let scores = sessionVolumeScores(from: stats.recentSets)
        guard scores.count >= 2 else { return 0 }
        let recent = Array(scores.suffix(stallSessionThreshold + 1))
        guard recent.count >= 2 else { return 0 }

        var stalls = 0
        for index in 1..<recent.count {
            if recent[index] <= recent[index - 1] {
                stalls += 1
            } else {
                stalls = 0
            }
        }
        return stalls
    }

    /// Exercise IDs flagged for variation, merged with any explicit exclusions.
    static func avoidExerciseIds(
        from stats: [UserExerciseStats],
        additional: [String] = []
    ) -> [String] {
        Array(Set(additional + stats.filter(\.preferVariation).map(\.exerciseId))).sorted()
    }

    private static func volumeScore(_ set: CompletedSet) -> Double {
        (set.weightKg ?? 0) * Double(max(set.reps, 1))
    }
}
