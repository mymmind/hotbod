import Foundation

/// Discrete prefs for the Today kettlebell circuit (exercises × reps × rounds + rests).
struct KettlebellCircuitScheme: Codable, Hashable, Sendable {
    var exerciseCount: Int
    var reps: Int
    var rounds: Int
    var transitionRestSeconds: Int
    var roundRestSeconds: Int

    static let exerciseCountOptions = Array(3...6)
    static let repsOptions = Array(3...8)
    static let roundsOptions = Array(3...8)
    static let transitionRestOptions = [10, 15, 20]
    static let roundRestOptions = [45, 60, 90, 120]

    static var `default`: KettlebellCircuitScheme {
        let c = GenerationConstants.KettlebellCircuit.self
        return KettlebellCircuitScheme(
            exerciseCount: c.exerciseCount,
            reps: c.reps,
            rounds: c.rounds,
            transitionRestSeconds: c.transitionRestSeconds,
            roundRestSeconds: c.roundRestSeconds
        )
    }

    /// Maps each field onto the nearest allowed picker value.
    var clamped: KettlebellCircuitScheme {
        KettlebellCircuitScheme(
            exerciseCount: Self.nearest(exerciseCount, in: Self.exerciseCountOptions),
            reps: Self.nearest(reps, in: Self.repsOptions),
            rounds: Self.nearest(rounds, in: Self.roundsOptions),
            transitionRestSeconds: Self.nearest(transitionRestSeconds, in: Self.transitionRestOptions),
            roundRestSeconds: Self.nearest(roundRestSeconds, in: Self.roundRestOptions)
        )
    }

    private static func nearest(_ value: Int, in options: [Int]) -> Int {
        options.min(by: { abs($0 - value) < abs($1 - value) }) ?? value
    }
}
