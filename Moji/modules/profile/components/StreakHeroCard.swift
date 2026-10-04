import SwiftUI

struct StreakHeroCard: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: ProfileServicesStore { .shared }
    private var interactions: ProfileInteractionsStore { .shared }

    var body: some View {
        let activity = service.activity
        let week = service.week()

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(streakLine(activity.currentStreak))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.text.secondary)
                    .contentTransition(.numericText(value: Double(activity.currentStreak)))

                Spacer(minLength: 0)

                Image(systemName: "flame.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(activity.isTodayDone ? MojiTint.flame : theme.text.secondary.opacity(0.35))
                    .symbolEffect(.bounce, value: activity.currentStreak)
            }

            Text(statusText(activity))
                .font(.system(size: 15))
                .foregroundStyle(theme.text.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 0) {
                ForEach(week) { day in
                    StreakWeekDayView(day: day)
                        .frame(maxWidth: .infinity)
                }
            }

            if !activity.isTodayDone {
                ProgressCapsuleButton(
                    title: String(localized: "Go to lessons"),
                    role: .primary,
                    height: 50,
                    action: { interactions.openLearn() }
                )
            }
        }
        .profileCard()
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: activity.isTodayDone)
    }

    private func streakLine(_ count: Int) -> AttributedString {
        var line = AttributedString(localized: "\(count) day streak")
        if let range = line.range(of: String(count)) {
            line[range].font = .system(size: 52, weight: .bold).monospacedDigit()
            line[range].foregroundColor = theme.text.primary
        }
        return line
    }

    private func statusText(_ activity: MojiActivitySummary) -> String {
        if activity.isTodayDone {
            let done = MojiAlphabetCatalog.shared.pages
                .filter { activity.pagesDoneToday.contains($0) }
                .map(\.title)
                .joined(separator: ", ")
            guard !done.isEmpty else {
                return String(localized: "Done for today. See you tomorrow.")
            }
            return String(localized: "Done for today: \(done). See you tomorrow.")
        }
        if activity.currentStreak > 0 {
            return String(localized: "Finish a lesson or a practice session today to keep it going.")
        }
        return String(localized: "Finish a lesson or a practice session to start a streak.")
    }
}

private struct StreakWeekDayView: View {
    let day: ProfileWeekDay

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        VStack(spacing: 7) {
            Text(day.symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(day.isToday ? theme.text.primary : theme.text.secondary)

            ZStack {
                if day.isDone {
                    Circle()
                        .fill(MojiTint.flame)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white)
                } else if day.isToday {
                    Circle()
                        .strokeBorder(theme.text.primary.opacity(0.7), lineWidth: 1.5)
                } else {
                    Circle()
                        .fill(theme.bg._500.opacity(day.isFuture ? 0.5 : 1))
                }
            }
            .frame(width: 28, height: 28)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(day.isDone ? String(localized: "\(day.symbol), done") : day.symbol))
    }
}
