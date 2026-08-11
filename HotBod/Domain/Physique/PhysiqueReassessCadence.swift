import Foundation

enum PhysiqueReassessCadence {
    static let intervalWeeks = 6
    static let notificationIdentifier = "hotbod.physique.reassess"

    static func dueDate(from createdAt: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .weekOfYear, value: intervalWeeks, to: createdAt) ?? createdAt
    }

    static func isDue(
        assessmentCreatedAt: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        now >= dueDate(from: assessmentCreatedAt, calendar: calendar)
    }

    static func nextFireDateComponents(
        from createdAt: Date,
        timeOfDay: TimeOfDayPreference,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DateComponents? {
        let due = dueDate(from: createdAt, calendar: calendar)
        guard due > now else { return nil }

        var preferred = calendar.dateComponents([.year, .month, .day], from: due)
        preferred.hour = timeOfDay.reminderHour
        preferred.minute = 0
        preferred.second = 0

        if let preferredFire = calendar.date(from: preferred), preferredFire > now {
            return preferred
        }

        // Preferred clock already passed, but not yet past due → fire at due instant.
        return calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: due
        )
    }
}
