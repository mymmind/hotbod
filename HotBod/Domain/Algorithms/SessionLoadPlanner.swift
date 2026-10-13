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
        let scaled: Double
        if input.sessionMode == .recovery {
            scaled = base * GenerationConstants.RecoverySession.weightMultiplier
        } else if input.isInDeloadWeek {
            scaled = base * GenerationConstants.Deload.loadMultiplier
        } else if input.returningFromBreak {
            scaled = base * GenerationConstants.Deload.reEntryWeightMultiplier
        } else {
            scaled = base
        }
        return GenerationConstants.Weight.roundToAvailable(
            scaled,
            equipment: input.equipment,
            ceilings: input.ceilings
        )
    }
}
