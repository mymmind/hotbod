import Foundation

enum SessionLoadPlanner {
    struct Input {
        var suggestedNextWeightKg: Double?
        var lastWeightKg: Double?
        var sessionMode: SessionMode
        var isInDeloadWeek: Bool
        var returningFromBreak: Bool
        var equipment: [Equipment]
        var ceilings: [Equipment: Double]
        var fallbackWeightKg: Double
    }

    static func plannedWeightKg(_ input: Input) -> Double {
        let base = input.suggestedNextWeightKg ?? input.lastWeightKg ?? input.fallbackWeightKg
        let multiplier: Double?
        if input.sessionMode == .recovery {
            multiplier = GenerationConstants.RecoverySession.weightMultiplier
        } else if input.isInDeloadWeek {
            multiplier = GenerationConstants.Deload.loadMultiplier
        } else if input.returningFromBreak {
            multiplier = GenerationConstants.Deload.reEntryWeightMultiplier
        } else {
            multiplier = nil
        }
        let scaled = scaledLoad(base, multiplier: multiplier)
        let rounded = GenerationConstants.Weight.roundToAvailable(
            scaled,
            equipment: input.equipment,
            ceilings: input.ceilings
        )
        guard base < 0 else { return rounded }
        return max(rounded, GenerationConstants.Validation.minLoggedWeightKg)
    }

    /// A fraction below 1 reduces a positive load and increases assistance on a negative load.
    private static func scaledLoad(_ base: Double, multiplier: Double?) -> Double {
        guard let multiplier, multiplier > 0 else { return base }
        if base < 0 {
            return base / multiplier
        }
        return base * multiplier
    }
}
