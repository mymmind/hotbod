import Foundation

enum ProfileScheduleEditing {
    static func reconcileSchedule(_ profile: inout UserProfile) {
        let selected = Set(profile.reminderTrainingDays)
        profile.reminderTrainingDays = Weekday.allCases.filter(selected.contains)
    }

    static func hasValidSchedule(_ profile: UserProfile) -> Bool {
        Set(profile.reminderTrainingDays).count >= 2
    }

    @discardableResult
    static func toggleTrainingDay(_ day: Weekday, in profile: inout UserProfile) -> Bool {
        if profile.reminderTrainingDays.contains(day) {
            guard Set(profile.reminderTrainingDays).count > 2 else { return false }
            profile.reminderTrainingDays.removeAll { $0 == day }
        } else {
            profile.reminderTrainingDays.append(day)
        }
        reconcileSchedule(&profile)
        return true
    }
}
