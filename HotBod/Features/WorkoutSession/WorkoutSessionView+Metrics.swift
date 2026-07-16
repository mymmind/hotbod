import SwiftUI

struct ExerciseCompleteSummary {
    let setsCompleted: Int
    let volumeKg: Double
    let bestSetDescription: String?
    let averageRPE: Double?
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
        let working = exercise.completedSets.filter { !$0.isWarmup && !$0.isCooldown }
        let volume = working.reduce(0.0) { partial, set in
            partial + (set.weightKg ?? 0) * Double(max(set.reps, 1))
        }
        let best = working.max { lhs, rhs in
            (lhs.weightKg ?? 0) * Double(lhs.reps) < (rhs.weightKg ?? 0) * Double(rhs.reps)
        }
        let bestDescription: String?
        if let best {
            if let duration = best.durationSeconds {
                bestDescription = "\(duration)s"
            } else if let distance = best.distanceMeters {
                bestDescription = "\(Int(distance))m"
            } else if let weight = best.weightKg {
                bestDescription = "\(Int(weight))\(meta.resolvedWeightDisplaySemantics.compactLoadUnit) × \(best.reps)"
            } else {
                bestDescription = "\(best.reps) reps"
            }
        } else {
            bestDescription = nil
        }
        return ExerciseCompleteSummary(
            setsCompleted: working.count,
            volumeKg: volume,
            bestSetDescription: bestDescription,
            averageRPE: EffortFeedbackMapping.averageEffectiveRPE(from: working)
        )
    }
}
