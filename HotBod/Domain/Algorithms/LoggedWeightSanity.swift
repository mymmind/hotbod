import Foundation

enum LoggedWeightSanity {
    enum HardBlockReason: Equatable {
        case negative
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
        if proposedKg < 0 {
            return .hardBlock(.negative)
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
}
