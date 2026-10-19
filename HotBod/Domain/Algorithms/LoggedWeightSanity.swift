import Foundation

enum LoggedWeightSanity {
    enum HardBlockReason: Equatable {
        case belowAbsoluteMin
        case aboveAbsoluteMax
    }

    enum Outcome: Equatable {
        case ok
        case softWarning(baselineKg: Double)
        case hardBlock(HardBlockReason)
    }

    static func evaluate(
        proposedKg: Double,
        lastWeightKg: Double?,
        plannedWeightKg: Double?
    ) -> Outcome {
        if proposedKg < GenerationConstants.Validation.minLoggedWeightKg {
            return .hardBlock(.belowAbsoluteMin)
        }
        if proposedKg > GenerationConstants.Validation.maxPlannedWeightKg {
            return .hardBlock(.aboveAbsoluteMax)
        }

        let baseline: Double?
        if let last = lastWeightKg, last > 0 {
            baseline = last
        } else if let planned = plannedWeightKg, planned > 0 {
            baseline = planned
        } else {
            baseline = nil
        }

        if let baseline,
           proposedKg > baseline * GenerationConstants.Validation.weightJumpWarningMultiplier {
            return .softWarning(baselineKg: baseline)
        }
        return .ok
    }

    /// Resistance settings are a machine level, not kilograms, so the jump warning does not apply.
    static func evaluateResistanceLevel(_ level: Double) -> Outcome {
        if level < 0 {
            return .hardBlock(.belowAbsoluteMin)
        }
        if level > GenerationConstants.Validation.maxResistanceLevel {
            return .hardBlock(.aboveAbsoluteMax)
        }
        return .ok
    }

    static func evaluateLoggedLoad(
        proposed: Double,
        semantics: WeightDisplaySemantics,
        lastWeightKg: Double?,
        plannedWeightKg: Double?
    ) -> Outcome {
        if semantics == .resistanceLevel {
            return evaluateResistanceLevel(proposed)
        }
        return evaluate(
            proposedKg: proposed,
            lastWeightKg: lastWeightKg,
            plannedWeightKg: plannedWeightKg
        )
    }
}
