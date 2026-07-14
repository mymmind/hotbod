// swiftlint:disable large_tuple
import SwiftUI

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
            let weightPart = weightSuffix(planned: planned, showWeightInput: showWeightInput, semantics: weightSemantics)
            return "\(seconds)s hold\(weightPart)"
        }
        if prescription == .distance || prescription == .distanceOrTime,
           let meters = planned.targetDistanceMeters {
            let weightPart = weightSuffix(planned: planned, showWeightInput: showWeightInput, semantics: weightSemantics)
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
            let unit = weightSemantics == .perHand ? "kg each" : "kg"
            let w = "\(Int(wKg))\(unit) × "
            if planned.isWarmup { return "Warm-up · \(w)\(range)" }
            if planned.isCooldown { return "Cooldown · \(w)\(range)" }
            return "\(w)\(range)"
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
        let unit = semantics == .perHand ? "kg each" : "kg"
        return " · \(Int(wKg))\(unit)"
    }

    func clearMetricTexts() {
        weightTexts = [:]
        repsTexts = [:]
        durationTexts = [:]
        distanceTexts = [:]
    }

    func exerciseCompleteSummary(for exercise: WorkoutExercise, meta: Exercise) -> (
        setsCompleted: Int,
        volumeKg: Double,
        bestSetDescription: String?,
        averageRPE: Double?
    ) {
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
                bestDescription = "\(Int(weight))kg × \(best.reps)"
            } else {
                bestDescription = "\(best.reps) reps"
            }
        } else {
            bestDescription = nil
        }
        return (
            working.count,
            volume,
            bestDescription,
            EffortFeedbackMapping.averageEffectiveRPE(from: working)
        )
    }
}
