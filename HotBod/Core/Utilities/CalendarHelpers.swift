import Foundation

extension Calendar {
    func daysAgo(_ days: Int, from referenceDate: Date = Date()) -> Date {
        date(byAdding: .day, value: -days, to: startOfDay(for: referenceDate))
            ?? startOfDay(for: referenceDate).addingTimeInterval(TimeInterval(-days * 86_400))
    }

    func startOfNextDay(after referenceDate: Date) -> Date {
        let start = startOfDay(for: referenceDate)
        return date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(86_400)
    }
}

enum URLBuilder {
    static func httpsURL(_ string: String) -> URL? {
        URL(string: string)
    }
}
