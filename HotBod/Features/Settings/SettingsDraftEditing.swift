import Foundation

enum SettingsDraftEditing {
    static func formatted(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.0f", value)
    }

    static func applyTextFields(
        draft: inout UserProfile,
        weightText: String,
        heightText: String,
        ageText: String,
        proteinText: String,
        limitationNotes: String
    ) {
        draft.weightKg = Double(weightText)
        draft.heightCm = Double(heightText)
        draft.age = Int(ageText)
        if let grams = Double(proteinText) {
            draft.proteinGoalGrams = grams
        }
        draft.limitationNotes = limitationNotes.isEmpty ? nil : limitationNotes
    }

    static func shouldRefreshWorkout(draft: UserProfile, comparedTo original: UserProfile) -> Bool {
        draft.goal != original.goal
            || draft.experienceLevel != original.experienceLevel
            || draft.trainingLocation != original.trainingLocation
            || draft.availableEquipment != original.availableEquipment
            || draft.trainingDaysPerWeek != original.trainingDaysPerWeek
            || draft.preferredSessionLengthMinutes != original.preferredSessionLengthMinutes
            || draft.preferredSplit != original.preferredSplit
            || draft.preferredTrainingDays != original.preferredTrainingDays
            || draft.timeOfDayPreference != original.timeOfDayPreference
            || draft.limitations != original.limitations
            || draft.limitationNotes != original.limitationNotes
            || draft.preferredMuscleGroups != original.preferredMuscleGroups
            || draft.avoidedMuscleGroups != original.avoidedMuscleGroups
            || draft.includeWarmupSets != original.includeWarmupSets
            || draft.includeCooldown != original.includeCooldown
            || draft.preferredExerciseGrouping != original.preferredExerciseGrouping
            || draft.preferredExerciseVariability != original.preferredExerciseVariability
            || draft.includeCoreFinisher != original.includeCoreFinisher
            || draft.includeConditioning != original.includeConditioning
            || draft.cardioBlockPlacement != original.cardioBlockPlacement
            || draft.maxAvailableWeightKg != original.maxAvailableWeightKg
    }

    static let weightLimitEquipment: [Equipment] = [.dumbbell, .barbell, .kettlebell]

    static func weightLimitedEquipment(in draft: UserProfile) -> [Equipment] {
        weightLimitEquipment.filter { draft.availableEquipment.contains($0) }
    }

    static func setEquipmentWeightLimit(equipment: Equipment, text: String, in draft: inout UserProfile) {
        if let value = Double(text), value > 0 {
            draft.maxAvailableWeightKg[equipment] = value
        } else {
            draft.maxAvailableWeightKg.removeValue(forKey: equipment)
        }
    }

    static func reconcileSchedule(_ draft: inout UserProfile) {
        let selected = Set(draft.preferredTrainingDays)
        draft.preferredTrainingDays = Weekday.allCases.filter(selected.contains)
        draft.trainingDaysPerWeek = draft.preferredTrainingDays.count
    }

    static func hasValidSchedule(_ draft: UserProfile) -> Bool {
        Set(draft.preferredTrainingDays).count >= 2
    }

    @discardableResult
    static func toggleTrainingDay(_ day: Weekday, in draft: inout UserProfile) -> Bool {
        if draft.preferredTrainingDays.contains(day) {
            guard Set(draft.preferredTrainingDays).count > 2 else { return false }
            draft.preferredTrainingDays.removeAll { $0 == day }
        } else {
            draft.preferredTrainingDays.append(day)
        }
        reconcileSchedule(&draft)
        return true
    }

    static func toggleEquipment(_ equipment: Equipment, in draft: inout UserProfile) {
        if draft.availableEquipment.contains(equipment) {
            draft.availableEquipment.removeAll { $0 == equipment }
        } else {
            draft.availableEquipment.append(equipment)
        }
    }

    static func toggleLimitation(_ limitation: BodyLimitation, in draft: inout UserProfile) {
        if limitation == .none {
            draft.limitations = [.none]
            return
        }
        draft.limitations.removeAll { $0 == .none }
        if draft.limitations.contains(limitation) {
            draft.limitations.removeAll { $0 == limitation }
        } else {
            draft.limitations.append(limitation)
        }
        if draft.limitations.isEmpty {
            draft.limitations = [.none]
        }
    }

    static func toggleAvoidedMuscle(_ muscle: MuscleGroup, in draft: inout UserProfile) {
        var avoided = draft.avoidedMuscleGroups ?? []
        var preferred = draft.preferredMuscleGroups ?? []
        if avoided.contains(muscle) {
            avoided.removeAll { $0 == muscle }
        } else {
            preferred.removeAll { $0 == muscle }
            avoided.append(muscle)
        }
        draft.avoidedMuscleGroups = avoided
        draft.preferredMuscleGroups = preferred
    }

    static func togglePreferredMuscle(_ muscle: MuscleGroup, in draft: inout UserProfile) {
        var preferred = draft.preferredMuscleGroups ?? []
        var avoided = draft.avoidedMuscleGroups ?? []
        if preferred.contains(muscle) {
            preferred.removeAll { $0 == muscle }
        } else {
            avoided.removeAll { $0 == muscle }
            preferred.append(muscle)
        }
        draft.preferredMuscleGroups = preferred
        draft.avoidedMuscleGroups = avoided
    }

    static func limitationsSummary(for draft: UserProfile) -> String {
        if draft.limitations.isEmpty || draft.limitations == [.none] {
            return "None"
        }
        return draft.limitations.map(\.displayName).joined(separator: ", ")
    }

    static func musclePreferencesSummary(for draft: UserProfile) -> String {
        let preferred = draft.preferredMuscleGroups ?? []
        let avoided = draft.avoidedMuscleGroups ?? []
        if preferred.isEmpty && avoided.isEmpty { return "None" }
        var parts: [String] = []
        if !preferred.isEmpty {
            parts.append("Prefer \(preferred.map(\.displayName).joined(separator: ", "))")
        }
        if !avoided.isEmpty {
            parts.append("Avoid \(avoided.map(\.displayName).joined(separator: ", "))")
        }
        return parts.joined(separator: " · ")
    }
}
