import Foundation
import Testing
@testable import Moji

@Suite("Streaks and the activity graph")
struct MojiStreakCalculatorTests {
    private let calendar = Calendar.current
    private let now = Date()

    private func key(daysAgo: Int) -> String {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        return MojiDayKey.make(date, calendar: calendar)
    }

    @Test func streakCountsThroughToday() {
        let days: Set<String> = [key(daysAgo: 0), key(daysAgo: 1), key(daysAgo: 2)]
        #expect(MojiStreakCalculator.currentStreak(days: days, now: now, calendar: calendar) == 3)
    }

    @Test func streakStaysAliveUntilMidnight() {
        let days: Set<String> = [key(daysAgo: 1), key(daysAgo: 2)]
        #expect(MojiStreakCalculator.currentStreak(days: days, now: now, calendar: calendar) == 2)
    }

    @Test func missedDayBreaksTheStreak() {
        let days: Set<String> = [key(daysAgo: 2), key(daysAgo: 3)]
        #expect(MojiStreakCalculator.currentStreak(days: days, now: now, calendar: calendar) == 0)
    }

    @Test func bestStreakFindsTheLongestRun() {
        let days: Set<String> = [
            key(daysAgo: 0), key(daysAgo: 1),
            key(daysAgo: 5), key(daysAgo: 6), key(daysAgo: 7), key(daysAgo: 8)
        ]
        #expect(MojiStreakCalculator.bestStreak(days: days, calendar: calendar) == 4)
    }

    @Test func dayKeyRoundTrips() throws {
        let date = try #require(MojiDayKey.date("2026-03-09", calendar: calendar))
        #expect(MojiDayKey.make(date, calendar: calendar) == "2026-03-09")
    }

    @Test func graphCoversTheWholeYear() throws {
        let year = calendar.component(.year, from: now)
        let graph = ContributionGraphBuilder.build(
            year: year,
            dayCounts: [key(daysAgo: 0): 2],
            now: now,
            calendar: calendar
        )
        let days = graph.weeks.flatMap(\.days).compactMap { $0 }
        let expected = try #require(calendar.range(of: .day, in: .year, for: now)).count

        #expect(days.count == expected)
        #expect(graph.weeks.allSatisfy { $0.days.count == 7 })
        #expect(graph.months.count == 12)
        #expect(graph.todayWeekIndex != nil)
        #expect(graph.sessions == 2)
    }
}
