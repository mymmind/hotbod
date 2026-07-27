import Foundation

struct MuscleRecoveryState: Codable, Hashable, Identifiable {
    var muscleGroup: MuscleGroup
    /// Derived preparedness (0...100) = clamp(100 + fitness - fatigue). Kept for UI/generation compatibility.
    var recoveryPercentage: Double
    var lastTrainedAt: Date?
    var accumulatedFatigue: Double
    /// Positive residual training effect (decays ~3× slower than fatigue).
    var fitness: Double
    /// Residual fatigue load.
    var fatigue: Double

    var id: String { muscleGroup.rawValue }

    enum CodingKeys: String, CodingKey {
        case muscleGroup, recoveryPercentage, lastTrainedAt, accumulatedFatigue, fitness, fatigue
    }

    init(
        muscleGroup: MuscleGroup,
        recoveryPercentage: Double,
        lastTrainedAt: Date? = nil,
        accumulatedFatigue: Double = 0,
        fitness: Double = 0,
        fatigue: Double? = nil
    ) {
        self.muscleGroup = muscleGroup
        self.lastTrainedAt = lastTrainedAt
        self.fitness = fitness
        if let fatigue {
            self.fatigue = fatigue
        } else if fitness == 0 {
            // Legacy single-value states: encode low recovery as fatigue load.
            self.fatigue = max(accumulatedFatigue, 100 - recoveryPercentage)
        } else {
            self.fatigue = accumulatedFatigue
        }
        self.accumulatedFatigue = self.fatigue
        self.recoveryPercentage = Self.preparedness(
            fitness: fitness,
            fatigue: self.fatigue,
            fallback: recoveryPercentage
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        muscleGroup = try container.decode(MuscleGroup.self, forKey: .muscleGroup)
        let decodedRecovery = try container.decode(Double.self, forKey: .recoveryPercentage)
        lastTrainedAt = try container.decodeIfPresent(Date.self, forKey: .lastTrainedAt)
        let decodedAccumulated = try container.decodeIfPresent(Double.self, forKey: .accumulatedFatigue) ?? 0
        let decodedFitness = try container.decodeIfPresent(Double.self, forKey: .fitness)
        let decodedFatigue = try container.decodeIfPresent(Double.self, forKey: .fatigue)
        fitness = decodedFitness ?? 0
        if let decodedFatigue {
            fatigue = decodedFatigue
        } else if decodedFitness == nil {
            // Pre-fitness/fatigue payloads: reconstruct fatigue from stored recovery %.
            fatigue = max(decodedAccumulated, 100 - decodedRecovery)
        } else {
            fatigue = decodedAccumulated
        }
        accumulatedFatigue = fatigue
        recoveryPercentage = Self.preparedness(
            fitness: fitness,
            fatigue: fatigue,
            fallback: decodedRecovery
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(muscleGroup, forKey: .muscleGroup)
        try container.encode(recoveryPercentage, forKey: .recoveryPercentage)
        try container.encodeIfPresent(lastTrainedAt, forKey: .lastTrainedAt)
        try container.encode(accumulatedFatigue, forKey: .accumulatedFatigue)
        try container.encode(fitness, forKey: .fitness)
        try container.encode(fatigue, forKey: .fatigue)
    }

    mutating func syncPreparedness() {
        accumulatedFatigue = fatigue
        recoveryPercentage = min(100, max(0, 100 + fitness - fatigue))
    }

    static func preparedness(fitness: Double, fatigue: Double, fallback: Double) -> Double {
        // Legacy single-value states (no fitness/fatigue tracked yet): keep explicit recovery.
        if fitness == 0, fatigue == 0, fallback != 100 {
            return min(100, max(0, fallback))
        }
        return min(100, max(0, 100 + fitness - fatigue))
    }
}
