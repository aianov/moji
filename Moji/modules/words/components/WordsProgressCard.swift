import SwiftUI

struct WordsProgressCard: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }

    var body: some View {
        let snapshot = service.snapshot
        let progress = snapshot.progress
        let total = max(1, progress.words)
        let isDoneToday = snapshot.todayStats.answers > 0

        Button {
            MojiHaptics.selection()
            MainTabRouter.shared.select(.words)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Words")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(theme.text.primary)
                    Spacer(minLength: 0)
                    if isDoneToday {
                        Label("Today", systemImage: "checkmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.text.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.text.secondary)
                }

                HStack(spacing: 14) {
                    WordsProgressRing(
                        seen: Double(progress.seenWords) / Double(total),
                        mature: Double(progress.matureWords) / Double(total),
                        size: 54,
                        lineWidth: 4,
                        label: "語"
                    )
                    VStack(alignment: .leading, spacing: 7) {
                        ProgressBarUi(
                            progress: Double(progress.matureWords) / Double(total),
                            height: 5,
                            track: theme.bg._600,
                            fill: MojiTint.gold
                        )
                        Text("Mature \(progress.matureWords) of \(progress.words), learning \(progress.youngWords)")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.text.secondary)
                        Text("Due now: \(snapshot.queue.review + snapshot.queue.learning) · new today: \(snapshot.queue.new)")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.text.secondary)
                    }
                }
            }
            .profileCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.98))
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens the Words tab"))
    }
}
