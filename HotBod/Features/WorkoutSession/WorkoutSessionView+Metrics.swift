import SwiftUI

struct ExerciseCompleteSummary {
    let setsCompleted: Int
    let volumeKg: Double
    let bestSetDescription: String?
    let averageRPE: Double?

    /// Builds the Exercise Complete interstitial stats from working sets only.
    static func make(
        completedSets: [CompletedSet],
        weightSemantics: WeightDisplaySemantics
    ) -> ExerciseCompleteSummary {
        let working = completedSets.filter { !$0.isWarmup && !$0.isCooldown }
        let volume = working.reduce(0.0) { partial, set in
            partial + WorkoutSessionCalculator.volumeContribution(for: set)
        }
        let best = working.max { lhs, rhs in
            setScore(lhs) < setScore(rhs)
        }
        return ExerciseCompleteSummary(
            setsCompleted: working.count,
            volumeKg: volume,
            bestSetDescription: best.map { bestSetDescription(for: $0, weightSemantics: weightSemantics) },
            averageRPE: EffortFeedbackMapping.averageEffectiveRPE(from: working)
        )
    }

    private static func setScore(_ set: CompletedSet) -> Double {
        WorkoutSessionCalculator.volumeContribution(for: set)
    }

    private static func bestSetDescription(
        for set: CompletedSet,
        weightSemantics: WeightDisplaySemantics
    ) -> String {
        let loadPrefix: String? = set.weightKg.map { weight in
            "\(Int(weight))\(weightSemantics.compactLoadUnit)"
        }

        if let duration = set.durationSeconds, duration > 0 {
            if let loadPrefix {
                return "\(loadPrefix) × \(duration)s"
            }
            return "\(duration)s"
        }
        if let distance = set.distanceMeters, distance > 0 {
            let meters = Int(distance)
            if let loadPrefix {
                return "\(loadPrefix) × \(meters)m"
            }
            return "\(meters)m"
        }
        if let loadPrefix {
            return "\(loadPrefix) × \(set.reps)"
        }
        return "\(set.reps) reps"
    }
}

extension WorkoutSessionView {
    func metricLabel(for meta: Exercise) -> String {
        meta.resolvedPrescriptionType.sessionMetricLabel
    }

    func weightLabel(for meta: Exercise, showWeightInput: Bool) -> String {
        guard showWeightInput else { return "BW" }
        return meta.resolvedWeightDisplaySemantics.sessionWeightLabel
    }

    func usesRepMetric(for meta: Exercise) -> Bool {
        meta.resolvedPrescriptionType == .reps
    }

    func usesDurationMetric(for meta: Exercise) -> Bool {
        switch meta.resolvedPrescriptionType {
        case .time, .distanceOrTime: true
        default: false
        }
    }

    func usesDistanceMetric(for meta: Exercise) -> Bool {
        switch meta.resolvedPrescriptionType {
        case .distance, .distanceOrTime: true
        default: false
        }
    }

    func targetText(_ planned: PlannedSet, meta: Exercise, showWeightInput: Bool) -> String {
        let prescription = meta.resolvedPrescriptionType
        let weightSemantics = meta.resolvedWeightDisplaySemantics

        if prescription == .time, let seconds = planned.targetDurationSeconds {
            let weightPart = weightSuffix(
                planned: planned,
                showWeightInput: showWeightInput,
                semantics: weightSemantics
            )
            return "\(seconds)s hold\(weightPart)"
        }
        if prescription == .distance || prescription == .distanceOrTime,
           let meters = planned.targetDistanceMeters {
            let weightPart = weightSuffix(
                planned: planned,
                showWeightInput: showWeightInput,
                semantics: weightSemantics
            )
            return "\(Int(meters))m\(weightPart)"
        }

        let range: String
        if planned.isMaxEffort {
            range = "\(planned.targetRepsMin)+ AMRAP"
        } else {
            range = "\(planned.targetRepsMin)–\(planned.targetRepsMax)"
        }

        guard showWeightInput else {
            if planned.isWarmup { return "Warm-up · BW · \(range)" }
            if planned.isCooldown { return "Cooldown · BW · \(range)" }
            return "BW · \(range)"
        }

        if let wKg = planned.targetWeightKg {
            let unit = weightSemantics.compactLoadUnit
            let weightPrefix = "\(Int(wKg))\(unit) × "
            if planned.isWarmup { return "Warm-up · \(weightPrefix)\(range)" }
            if planned.isCooldown { return "Cooldown · \(weightPrefix)\(range)" }
            return "\(weightPrefix)\(range)"
        }

        if planned.isWarmup { return "Warm-up · Load · \(range)" }
        if planned.isCooldown { return "Cooldown · \(range)" }
        return "Load · \(range)"
    }

    private func weightSuffix(
        planned: PlannedSet,
        showWeightInput: Bool,
        semantics: WeightDisplaySemantics
    ) -> String {
        guard showWeightInput, let wKg = planned.targetWeightKg else { return "" }
        let unit = semantics.compactLoadUnit
        return " · \(Int(wKg))\(unit)"
    }

    func setLabelColor(isDone: Bool, isActive: Bool, planned: PlannedSet) -> Color {
        if planned.isWarmup {
            return isDone ? ForgeColors.textSecondary : ForgeColors.textPrimary
        }
        if isDone { return ForgeColors.accentGreen }
        return isActive ? ForgeColors.textPrimary : ForgeColors.textSecondary
    }

    func clearMetricTexts() {
        weightTexts = [:]
        repsTexts = [:]
        durationTexts = [:]
        distanceTexts = [:]
    }

    func exerciseCompleteSummary(for exercise: WorkoutExercise, meta: Exercise) -> ExerciseCompleteSummary {
        ExerciseCompleteSummary.make(
            completedSets: exercise.completedSets,
            weightSemantics: meta.resolvedWeightDisplaySemantics
        )
    }
}
