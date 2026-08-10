import Foundation

extension PhysiqueFocusMuscle {
    var muscleGroups: [MuscleGroup] {
        switch self {
        case .lateralDelts, .rearDelts, .shoulders:
            [.shoulders]
        case .lats:
            [.back]
        case .upperChest, .chest:
            [.chest]
        case .traps:
            [.traps]
        case .biceps:
            [.biceps]
        case .triceps:
            [.triceps]
        case .abs:
            [.abs]
        case .glutes:
            [.glutes]
        case .quads:
            [.quads]
        case .hamstrings:
            [.hamstrings]
        case .calves:
            [.calves]
        }
    }
}
