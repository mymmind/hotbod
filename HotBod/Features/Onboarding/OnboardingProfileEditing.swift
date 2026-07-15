import Foundation

enum OnboardingProfileEditing {
    static let defaultWeightKg = 80.0
    static let defaultHeightCm = 175.0
    static let defaultAge = 30

    /// Applies safe defaults and reconciles conflicting onboarding draft fields before persistence.
    static func normalizeForCompletion(_ profile: inout UserProfile, lockSplit: Bool = false) {
        normalizeBodyStats(&profile)
        normalizeLimitations(&profile)
        if profile.availableEquipment.isEmpty {
            profile.availableEquipment = defaultEquipment(for: profile.trainingLocation)
        }
        reconcileSchedule(&profile)
        if !lockSplit {
            profile.preferredSplit = suggestedSplit(for: profile.trainingDaysPerWeek)
        }
    }

    static func normalizeBodyStats(_ profile: inout UserProfile) {
        if profile.weightKg == nil { profile.weightKg = defaultWeightKg }
        if profile.heightCm == nil { profile.heightCm = defaultHeightCm }
        if profile.age == nil { profile.age = defaultAge }
    }

    static func applyBodyStatsText(
        weightText: String,
        heightText: String,
        ageText: String,
        to profile: inout UserProfile
    ) {
        if let weight = Double(weightText.trimmingCharacters(in: .whitespaces)) {
            profile.weightKg = weight
        }
        if let height = Double(heightText.trimmingCharacters(in: .whitespaces)) {
            profile.heightCm = height
        }
        if let age = Int(ageText.trimmingCharacters(in: .whitespaces)) {
            profile.age = age
        }
        normalizeBodyStats(&profile)
    }

    static func normalizeLimitations(_ profile: inout UserProfile) {
        if profile.limitations.isEmpty {
            profile.limitations = [.none]
        }
    }

    static func defaultEquipment(for location: TrainingLocation) -> [Equipment] {
        switch location {
        case .bodyweightOnly:
            [.bodyweight]
        case .homeGym:
            [.bodyweight, .dumbbell, .bench, .pullUpBar, .resistanceBand, .kettlebell]
        case .commercialGym, .mixed:
            Equipment.allCases
        }
    }

    static func applyLocation(_ location: TrainingLocation, to profile: inout UserProfile) {
        let locationChanged = profile.trainingLocation != location
        profile.trainingLocation = location
        if locationChanged {
            profile.availableEquipment = defaultEquipment(for: location)
        }
    }

    static func applySuggestedSplit(to profile: inout UserProfile) {
        profile.preferredSplit = suggestedSplit(for: profile.trainingDaysPerWeek)
    }

    static func toggleEquipment(_ equipment: Equipment, in profile: inout UserProfile) {
        if profile.availableEquipment.contains(equipment) {
            guard profile.availableEquipment.count > 1 else { return }
            profile.availableEquipment.removeAll { $0 == equipment }
        } else {
            profile.availableEquipment.append(equipment)
        }
    }

    static func hasValidSchedule(_ profile: UserProfile) -> Bool {
        ProfileScheduleEditing.hasValidSchedule(profile)
    }

    @discardableResult
    static func toggleTrainingDay(_ day: Weekday, in profile: inout UserProfile) -> Bool {
        ProfileScheduleEditing.toggleTrainingDay(day, in: &profile)
    }

    static func reconcileSchedule(_ profile: inout UserProfile) {
        ProfileScheduleEditing.reconcileSchedule(&profile)
    }

    static func suggestedSplit(for daysPerWeek: Int) -> TrainingSplit {
        switch daysPerWeek {
        case ...3: .fullBody
        case 4: .upperLower
        case 5...6: .pushPullLegs
        default: .adaptive
        }
    }

    static func suggestedProteinGoal(for profile: UserProfile) -> Double {
        ProteinGoalCalculator.suggestedGoal(
            bodyWeightKg: profile.weightKg ?? defaultWeightKg,
            goal: profile.goal
        )
    }
}
