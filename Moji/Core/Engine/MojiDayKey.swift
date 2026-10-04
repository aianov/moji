import Foundation

enum MojiDayKey {
    static func make(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return format(
            year: components.year ?? 0,
            month: components.month ?? 0,
            day: components.day ?? 0
        )
    }

    static func date(_ key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(
            from: DateComponents(
                year: parts[0],
                month: parts[1],
                day: parts[2]
            )
        )
    }

    static func year(_ key: String) -> Int? {
        key.split(separator: "-").first.flatMap { Int($0) }
    }

    private static func format(year: Int, month: Int, day: Int) -> String {
        "\(pad(year, width: 4))-\(pad(month, width: 2))-\(pad(day, width: 2))"
    }

    private static func pad(_ value: Int, width: Int) -> String {
        let digits = String(value)
        guard digits.count < width else { return digits }
        return String(repeating: "0", count: width - digits.count) + digits
    }
}
