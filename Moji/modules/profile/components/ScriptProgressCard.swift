import SwiftUI

struct ScriptProgressCard: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: ProfileServicesStore { .shared }

    var body: some View {
        let doneToday = service.activity.pagesDoneToday

        VStack(alignment: .leading, spacing: 16) {
            Text("Mastery")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(theme.text.primary)

            ForEach([MojiPage.hiragana, .katakana]) { page in
                ScriptProgressRow(
                    symbol: page.symbol,
                    title: page.title,
                    stats: service.stats(for: page),
                    isDoneToday: doneToday.contains(page)
                )
            }

            VStack(alignment: .leading, spacing: 14) {
                ScriptProgressRow(
                    symbol: MojiScript.kanji.symbol,
                    title: MojiScript.kanji.title,
                    stats: service.stats(for: .kanji),
                    isDoneToday: doneToday.contains { $0.isKanji }
                )

                KanjiThemeProgressGrid(
                    themes: service.kanjiThemes,
                    stats: { service.stats(for: .kanji($0)) },
                    isDoneToday: { doneToday.contains(.kanji($0)) }
                )
            }
        }
        .profileCard()
    }
}

private struct ScriptProgressRow: View {
    let symbol: String
    let title: String
    let stats: MojiPageStats
    let isDoneToday: Bool

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        HStack(spacing: 14) {
            GlyphText(text: symbol, size: 21, color: theme.text.primary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.bg._500)
                )

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(theme.text.primary)
                    Spacer(minLength: 0)
                    if isDoneToday {
                        Label("Today", systemImage: "checkmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.text.secondary)
                    }
                }

                ProgressBarUi(
                    progress: stats.total > 0 ? Double(stats.mastered) / Double(stats.total) : 0,
                    height: 5,
                    track: theme.bg._600,
                    fill: MojiTint.gold
                )

                Text("Mastered \(stats.mastered) of \(stats.total), seen \(stats.practiced)")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.text.secondary)
            }
        }
    }
}

private struct KanjiThemeProgressGrid: View {
    let themes: [MojiKanjiTheme]
    let stats: (MojiKanjiTheme) -> MojiPageStats
    let isDoneToday: (MojiKanjiTheme) -> Bool

    private static let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8, alignment: .top),
        count: 5
    )

    var body: some View {
        LazyVGrid(columns: Self.columns, alignment: .center, spacing: 12) {
            ForEach(themes) { kanjiTheme in
                KanjiThemeProgressTile(
                    kanjiTheme: kanjiTheme,
                    stats: stats(kanjiTheme),
                    isDoneToday: isDoneToday(kanjiTheme)
                )
            }
        }
    }
}

private struct KanjiThemeProgressTile: View {
    let kanjiTheme: MojiKanjiTheme
    let stats: MojiPageStats
    let isDoneToday: Bool

    private static let ringSize: CGFloat = 44
    private static let ringWidth: CGFloat = 3.5

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let total = Double(max(1, stats.total))
        let seen = Double(stats.practiced) / total
        let mastered = Double(stats.mastered) / total

        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(theme.bg._600, lineWidth: Self.ringWidth)
                Circle()
                    .trim(from: 0, to: seen)
                    .stroke(MojiTint.gold.opacity(0.35), style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle()
                    .trim(from: 0, to: mastered)
                    .stroke(MojiTint.gold, style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                GlyphText(
                    text: kanjiTheme.symbol,
                    size: 18,
                    color: stats.mastered == stats.total && stats.total > 0 ? MojiTint.gold : theme.text.primary
                )
            }
            .frame(width: Self.ringSize, height: Self.ringSize)
            .overlay(alignment: .topTrailing) {
                if isDoneToday {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(MojiTint.flame)
                        .background(Circle().fill(theme.bg._300))
                        .offset(x: 4, y: -4)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: stats)

            Text(kanjiTheme.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.text.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: "\(stats.mastered)/\(stats.total)")
                .font(.system(size: 9.5, weight: .medium).monospacedDigit())
                .foregroundStyle(theme.text.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(kanjiTheme.title), mastered \(stats.mastered) of \(stats.total), seen \(stats.practiced)"))
    }
}
