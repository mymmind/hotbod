import Foundation

enum ProfileScheduleEditing {
    static func reconcileSchedule(_ profile: inout UserProfile) {
        let selected = Set(profile.preferredTrainingDays)
        profile.preferredTrainingDays = Weekday.allCases.filter(selected.contains)
        profile.trainingDaysPerWeek = profile.preferredTrainingDays.count
    }

    static func hasValidSchedule(_ profile: UserProfile) -> Bool {
        Set(profile.preferredTrainingDays).count >= 2
    }

    @discardableResult
    static func toggleTrainingDay(_ day: Weekday, in profile: inout UserProfile) -> Bool {
        if profile.preferredTrainingDays.contains(day) {
            guard Set(profile.preferredTrainingDays).count > 2 else { return false }
            profile.preferredTrainingDays.removeAll { $0 == day }
        } else {
            profile.preferredTrainingDays.append(day)
        }
        reconcileSchedule(&profile)
        return true
    }
}
