import Foundation

enum MojiStreakCalculator {
    static func summary(
        log: MojiActivityLog,
        now: Date,
        calendar: Calendar
    ) -> MojiActivitySummary {
        let todayKey = MojiDayKey.make(now, calendar: calendar)

        var dayCounts: [String: Int] = [:]
        var pagesDoneToday: Set<MojiPage> = []
        for record in log.completed {
            dayCounts[record.dayKey, default: 0] += 1
            if record.dayKey == todayKey, let page = record.page {
                pagesDoneToday.insert(page)
            }
        }

        let days = Set(dayCounts.keys)
        let currentYear = calendar.component(.year, from: now)
        let firstYear = days.compactMap(MojiDayKey.year).min().map { min($0, currentYear) } ?? currentYear

        return MojiActivitySummary(
            todayKey: todayKey,
            dayCounts: dayCounts,
            currentStreak: currentStreak(days: days, now: now, calendar: calendar),
            bestStreak: bestStreak(days: days, calendar: calendar),
            isTodayDone: days.contains(todayKey),
            practicedDays: days.count,
            totalSessions: log.completed.count,
            pagesDoneToday: pagesDoneToday,
            firstYear: firstYear
        )
    }

    static func currentStreak(
        days: Set<String>,
        now: Date,
        calendar: Calendar
    ) -> Int {
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(MojiDayKey.make(cursor, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(MojiDayKey.make(yesterday, calendar: calendar)) else {
                return 0
            }
            cursor = yesterday
        }

        var streak = 0
        while days.contains(MojiDayKey.make(cursor, calendar: calendar)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    static func bestStreak(
        days: Set<String>,
        calendar: Calendar
    ) -> Int {
        let dates = days
            .compactMap { MojiDayKey.date($0, calendar: calendar) }
            .map { calendar.startOfDay(for: $0) }
            .sorted()

        var best = 0
        var run = 0
        var previous: Date?
        for date in dates {
            if let previous,
               let expected = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(expected, inSameDayAs: date) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = date
        }
        return best
    }
}
