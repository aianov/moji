import SwiftUI

struct ProfileStatsRow: View {
    private var service: ProfileServicesStore { .shared }

    var body: some View {
        let activity = service.activity

        HStack(spacing: 10) {
            ProfileStatTile(
                value: "\(activity.bestStreak)",
                title: String(localized: "Best streak")
            )
            ProfileStatTile(
                value: "\(activity.practicedDays)",
                title: String(localized: "Days")
            )
            ProfileStatTile(
                value: service.overallAccuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "-",
                title: String(localized: "Accuracy")
            )
        }
    }
}

private struct ProfileStatTile: View {
    let value: String
    let title: String

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .semibold).monospacedDigit())
                .foregroundStyle(theme.text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(theme.text.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .profileCard()
    }
}
