import Foundation

enum WatchLoadAdjuster {
    static func adjustedLoad(current: Double, delta: Double, unit: String) -> Double {
        let next = current + delta
        if unit == "lvl" {
            return min(
                GenerationConstants.Validation.maxResistanceLevel,
                max(0, next.rounded())
            )
        }
        let clamped = min(
            GenerationConstants.Validation.maxPlannedWeightKg,
            max(GenerationConstants.Validation.minLoggedWeightKg, next)
        )
        return (clamped * 2).rounded() / 2
    }

    static func adjustedSecondary(current: Int, delta: Int, label: String) -> Int {
        let next = current + delta
        switch label {
        case "sec":
            return min(3600, max(15, next))
        case "m":
            return min(10_000, max(5, next))
        default:
            return min(GenerationConstants.Validation.maxRepCount, max(1, next))
        }
    }
}
