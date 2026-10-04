import Foundation

struct ContributionDay: Identifiable, Equatable, Sendable {
    let key: String
    let date: Date
    let count: Int
    let isToday: Bool
    let isFuture: Bool

    var id: String { key }

    var level: Int {
        min(count, 3)
    }
}

struct ContributionWeek: Identifiable, Equatable, Sendable {
    let index: Int
    let days: [ContributionDay?]

    var id: Int { index }
}

struct ContributionMonthLabel: Identifiable, Equatable, Sendable {
    let weekIndex: Int
    let title: String

    var id: Int { weekIndex }
}

struct ContributionGraphModel: Equatable, Sendable {
    let year: Int
    let weeks: [ContributionWeek]
    let months: [ContributionMonthLabel]
    let weekdayLabels: [String?]
    let practicedDays: Int
    let sessions: Int
    let isCurrentYear: Bool
    let todayWeekIndex: Int?

    func day(forKey key: String) -> ContributionDay? {
        for week in weeks {
            for case let day? in week.days where day.key == key {
                return day
            }
        }
        return nil
    }
}

enum ContributionGraphBuilder {
    static func build(
        year: Int,
        dayCounts: [String: Int],
        now: Date,
        calendar: Calendar
    ) -> ContributionGraphModel {
        let currentYear = calendar.component(.year, from: now)
        let weekdayLabels = labels(calendar: calendar)

        guard let firstDay = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let nextYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else {
            return ContributionGraphModel(
                year: year,
                weeks: [],
                months: [],
                weekdayLabels: weekdayLabels,
                practicedDays: 0,
                sessions: 0,
                isCurrentYear: year == currentYear,
                todayWeekIndex: nil
            )
        }

        let today = calendar.startOfDay(for: now)
        let todayKey = MojiDayKey.make(now, calendar: calendar)
        let leadingDays = (calendar.component(.weekday, from: firstDay) - calendar.firstWeekday + 7) % 7
        var cursor = calendar.date(byAdding: .day, value: -leadingDays, to: firstDay) ?? firstDay

        let monthSymbols = calendar.shortMonthSymbols
        var weeks: [ContributionWeek] = []
        var months: [ContributionMonthLabel] = []
        var practicedDays = 0
        var sessions = 0
        var todayWeekIndex: Int?

        while cursor < nextYear {
            var days: [ContributionDay?] = []
            for _ in 0..<7 {
                if cursor >= firstDay, cursor < nextYear {
                    let key = MojiDayKey.make(cursor, calendar: calendar)
                    let count = dayCounts[key] ?? 0
                    if count > 0 {
                        practicedDays += 1
                        sessions += count
                    }
                    if key == todayKey {
                        todayWeekIndex = weeks.count
                    }
                    days.append(
                        ContributionDay(
                            key: key,
                            date: cursor,
                            count: count,
                            isToday: key == todayKey,
                            isFuture: cursor > today
                        )
                    )

                    if calendar.component(.day, from: cursor) == 1 {
                        let month = calendar.component(.month, from: cursor)
                        if month - 1 < monthSymbols.count {
                            months.append(
                                ContributionMonthLabel(
                                    weekIndex: weeks.count,
                                    title: monthSymbols[month - 1]
                                )
                            )
                        }
                    }
                } else {
                    days.append(nil)
                }
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor)
                    ?? cursor.addingTimeInterval(86_400)
            }
            weeks.append(ContributionWeek(index: weeks.count, days: days))
        }

        return ContributionGraphModel(
            year: year,
            weeks: weeks,
            months: months,
            weekdayLabels: weekdayLabels,
            practicedDays: practicedDays,
            sessions: sessions,
            isCurrentYear: year == currentYear,
            todayWeekIndex: todayWeekIndex
        )
    }

    private static func labels(calendar: Calendar) -> [String?] {
        let symbols = calendar.shortWeekdaySymbols
        return (0..<7).map { row in
            let weekday = (calendar.firstWeekday - 1 + row) % 7 + 1
            guard [2, 4, 6].contains(weekday), weekday - 1 < symbols.count else { return nil }
            return symbols[weekday - 1]
        }
    }
}

struct ProfileWeekDay: Identifiable, Equatable, Sendable {
    let key: String
    let symbol: String
    let isDone: Bool
    let isToday: Bool
    let isFuture: Bool

    var id: String { key }
}

enum ProfileWeekBuilder {
    static func build(
        dayCounts: [String: Int],
        now: Date,
        calendar: Calendar
    ) -> [ProfileWeekDay] {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        let symbols = calendar.veryShortStandaloneWeekdaySymbols

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let key = MojiDayKey.make(date, calendar: calendar)
            let weekday = calendar.component(.weekday, from: date)
            return ProfileWeekDay(
                key: key,
                symbol: weekday - 1 < symbols.count ? symbols[weekday - 1] : "",
                isDone: (dayCounts[key] ?? 0) > 0,
                isToday: calendar.isDate(date, inSameDayAs: today),
                isFuture: date > today
            )
        }
    }
}
