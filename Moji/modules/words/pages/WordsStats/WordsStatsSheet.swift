import Charts
import SwiftUI

struct WordsStatsSheet: View {
    static let chartDays = 30

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        let snapshot = service.snapshot
        let today = snapshot.today
        let todayStats = snapshot.todayStats

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    WordsStatsToday(stats: todayStats, streak: service.activity.currentStreak)
                    WordsStatsCounts(states: snapshot.states)
                    WordsStatsAnswersChart(
                        days: MojiWordStats.answers(snapshot.days, from: today - Self.chartDays + 1, through: today)
                    )
                    WordsStatsForecastChart(
                        counts: MojiWordStats.forecast(
                            catalog: snapshot.catalog,
                            cards: snapshot.cards,
                            options: snapshot.options,
                            today: today,
                            days: Self.chartDays
                        ),
                        today: today
                    )
                    WordsStatsRetention(days: snapshot.days, today: today)
                    WordsStatsTime(days: snapshot.days, today: today)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background {
                AppBackground()
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        interactions.closeSheet()
                    }
                }
            }
        }
    }
}

private struct WordsStatsTitle: View {
    let text: String
    var detail: String? = nil

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.text.primary)
            Spacer(minLength: 0)
            if let detail {
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.text.secondary)
            }
        }
    }
}

private struct WordsStatsToday: View {
    let stats: MojiWordDayStats
    let streak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WordsStatsTitle(text: String(localized: "Today"))
            HStack(spacing: 10) {
                WordsCountTile(value: stats.answers, title: String(localized: "Answers"))
                WordsCountTile(value: stats.newCards, title: String(localized: "New"))
                WordsCountTile(value: stats.againCount, title: String(localized: "Again"))
            }
            HStack(spacing: 10) {
                WordsStatsValue(value: WordsFormat.duration(stats.seconds), title: String(localized: "Time"))
                WordsStatsValue(
                    value: stats.answers > 0 ? WordsFormat.percent(Double(stats.answers - stats.againCount) / Double(stats.answers)) : "-",
                    title: String(localized: "Without Again")
                )
                WordsStatsValue(value: "\(streak)", title: String(localized: "Day streak"))
            }
        }
        .wordsCard()
    }
}

private struct WordsStatsValue: View {
    let value: String
    let title: String

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value)
                .font(.system(size: 17, weight: .semibold).monospacedDigit())
                .foregroundStyle(theme.text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.text.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WordsStatsCounts: View {
    let states: MojiWordStateCounts

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    private var rows: [(MojiWordCardState, Color)] {
        [
            (.new, theme.text.primary.opacity(0.18)),
            (.learning, theme.text.primary.opacity(0.4)),
            (.relearning, MojiTint.wrong.opacity(0.8)),
            (.young, MojiTint.gold.opacity(0.45)),
            (.mature, MojiTint.gold),
            (.suspended, theme.text.primary.opacity(0.65)),
            (.buried, theme.text.primary.opacity(0.28))
        ]
    }

    var body: some View {
        let total = max(1, states.total)

        VStack(alignment: .leading, spacing: 14) {
            WordsStatsTitle(text: String(localized: "Cards"), detail: String(localized: "\(states.total) in all"))

            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(rows.filter { states.count($0.0) > 0 }, id: \.0) { state, color in
                        Rectangle()
                            .fill(color)
                            .frame(width: max(3, (geometry.size.width - 12) * CGFloat(states.count(state)) / CGFloat(total)))
                    }
                }
                .clipShape(Capsule(style: .continuous))
            }
            .frame(height: 12)
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                ForEach(rows, id: \.0) { state, color in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(color)
                            .frame(width: 10, height: 10)
                        Text(state.title)
                            .font(.system(size: 14))
                            .foregroundStyle(theme.text.primary)
                        Spacer(minLength: 0)
                        Text("\(states.count(state))")
                            .font(.system(size: 14, weight: .semibold).monospacedDigit())
                            .foregroundStyle(theme.text.primary)
                    }
                }
                Divider()
                HStack {
                    Text("Leeches")
                    Spacer(minLength: 0)
                    Text("\(states.leeches)")
                        .monospacedDigit()
                }
                .font(.system(size: 14))
                .foregroundStyle(theme.text.secondary)
                HStack {
                    Text("Flagged")
                    Spacer(minLength: 0)
                    Text("\(states.flagged)")
                        .monospacedDigit()
                }
                .font(.system(size: 14))
                .foregroundStyle(theme.text.secondary)
            }
            Text("Young cards have intervals under 21 days, mature ones 21 days or more.")
                .font(.system(size: 12))
                .foregroundStyle(theme.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .wordsCard()
    }
}

private struct WordsStatsAnswersChart: View {
    let days: [MojiWordDayStats]

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    private struct Bar: Identifiable {
        let id: String
        let date: Date
        let kind: String
        let count: Int
    }

    var body: some View {
        let learn = String(localized: "Learn")
        let review = String(localized: "Review")
        let relearn = String(localized: "Relearn")
        let bars = days.flatMap { day -> [Bar] in
            let date = WordsFormat.date(ofDay: day.day)
            return [
                Bar(id: "\(day.day)l", date: date, kind: learn, count: day.learnAnswers + day.cramAnswers),
                Bar(id: "\(day.day)r", date: date, kind: review, count: day.reviewAnswers),
                Bar(id: "\(day.day)x", date: date, kind: relearn, count: day.relearnAnswers)
            ]
        }
        let total = days.reduce(0) { $0 + $1.answers }
        let studied = days.filter { $0.answers > 0 }.count

        VStack(alignment: .leading, spacing: 14) {
            WordsStatsTitle(
                text: String(localized: "Answers a day"),
                detail: String(localized: "\(total) in 30 days · days studied: \(studied)")
            )
            Chart(bars) { bar in
                BarMark(
                    x: .value(String(localized: "Day"), bar.date, unit: .day),
                    y: .value(String(localized: "Answers"), bar.count)
                )
                .foregroundStyle(by: .value(String(localized: "Kind"), bar.kind))
            }
            .chartForegroundStyleScale([
                learn: theme.text.primary.opacity(0.35),
                review: theme.text.primary.opacity(0.85),
                relearn: MojiTint.wrong.opacity(0.85)
            ])
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 180)
        }
        .wordsCard()
    }
}

private struct WordsStatsForecastChart: View {
    let counts: [Int]
    let today: Int

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    private struct Bar: Identifiable {
        let id: Int
        let date: Date
        let count: Int
    }

    var body: some View {
        let bars = counts.enumerated().map { offset, count in
            Bar(id: offset, date: WordsFormat.date(ofDay: today + offset), count: count)
        }
        let tomorrow = counts.count > 1 ? counts[1] : 0
        let week = counts.prefix(7).reduce(0, +)

        VStack(alignment: .leading, spacing: 14) {
            WordsStatsTitle(
                text: String(localized: "Coming up"),
                detail: String(localized: "Tomorrow \(tomorrow), this week \(week)")
            )
            Chart(bars) { bar in
                BarMark(
                    x: .value(String(localized: "Day"), bar.date, unit: .day),
                    y: .value(String(localized: "Cards"), bar.count)
                )
                .foregroundStyle(theme.text.primary.opacity(bar.id == 0 ? 0.9 : 0.55))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 160)
            Text("Reviews due each day of the next month. Today includes cards already overdue.")
                .font(.system(size: 12))
                .foregroundStyle(theme.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .wordsCard()
    }
}

private struct WordsStatsRetention: View {
    let days: [Int: MojiWordDayStats]
    let today: Int

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    private var rows: [(String, MojiWordRetention)] {
        let first = days.keys.min() ?? today
        return [
            (String(localized: "Today"), MojiWordStats.retention(days, from: today, through: today)),
            (String(localized: "Yesterday"), MojiWordStats.retention(days, from: today - 1, through: today - 1)),
            (String(localized: "Last 7 days"), MojiWordStats.retention(days, from: today - 6, through: today)),
            (String(localized: "Last 30 days"), MojiWordStats.retention(days, from: today - 29, through: today)),
            (String(localized: "Last year"), MojiWordStats.retention(days, from: today - 364, through: today)),
            (String(localized: "All time"), MojiWordStats.retention(days, from: first, through: today))
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WordsStatsTitle(text: String(localized: "True retention"))
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text(verbatim: "")
                    header(String(localized: "Young"))
                    header(String(localized: "Mature"))
                    header(String(localized: "Total"))
                }
                ForEach(rows, id: \.0) { title, retention in
                    GridRow {
                        Text(title)
                            .font(.system(size: 14))
                            .foregroundStyle(theme.text.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        value(retention.young)
                        value(retention.mature)
                        value(retention.total, bold: true)
                    }
                }
            }
            Text("The share of review cards you remembered, without Again. Anki aims for about \(WordsFormat.percent(0.85))-\(WordsFormat.percent(0.9)).")
                .font(.system(size: 12))
                .foregroundStyle(theme.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .wordsCard()
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(theme.text.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func value(_ rate: Double?, bold: Bool = false) -> some View {
        Text(verbatim: WordsFormat.percent(rate))
            .font(.system(size: 14, weight: bold ? .semibold : .regular).monospacedDigit())
            .foregroundStyle(rate == nil ? theme.text.secondary : theme.text.primary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct WordsStatsTime: View {
    let days: [Int: MojiWordDayStats]
    let today: Int

    var body: some View {
        let week = MojiWordStats.seconds(days, from: today - 6, through: today)
        let month = MojiWordStats.seconds(days, from: today - 29, through: today)
        let total = MojiWordStats.seconds(days, from: Int.min, through: today)
        let streak = MojiWordStats.studyStreak(days, today: today)

        VStack(alignment: .leading, spacing: 14) {
            WordsStatsTitle(text: String(localized: "Time"))
            HStack(spacing: 10) {
                WordsStatsValue(value: WordsFormat.duration(week / 7), title: String(localized: "A day this week"))
                WordsStatsValue(value: WordsFormat.duration(month), title: String(localized: "30 days"))
                WordsStatsValue(value: WordsFormat.duration(total), title: String(localized: "All time"))
            }
            WordsStatsValue(value: "\(streak)", title: String(localized: "Days in a row with words"))
        }
        .wordsCard()
    }
}
