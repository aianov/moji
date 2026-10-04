import SwiftUI

struct PracticeSummaryView: View {
    let summary: PracticeSummaryModel

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: PracticeInteractionsStore { .shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                score
                numbers
                mistakes
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 44)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaBar(edge: .bottom) {
            ProgressCapsuleButton(
                title: String(localized: "Done"),
                role: .primary,
                action: { interactions.finish() }
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.page.fullTitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.text.secondary)
            Text("Session complete")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(theme.text.primary)
        }
    }

    private var score: some View {
        let percent = Int((summary.accuracy * 100).rounded())

        return VStack(alignment: .leading, spacing: 6) {
            Text("\(percent)%")
                .font(.system(size: 64, weight: .semibold).monospacedDigit())
                .foregroundStyle(theme.text.primary)
            Text("\(summary.correct) of \(summary.total) right")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.text.secondary)

            if summary.extendedStreak {
                Label {
                    Group {
                        if summary.streak <= 1 {
                            Text("Streak started: day 1")
                        } else {
                            Text("Day \(summary.streak) of your streak")
                        }
                    }
                    .foregroundStyle(theme.text.primary)
                } icon: {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(MojiTint.flame)
                }
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 8)
            }
        }
    }

    private var numbers: some View {
        let hairline = theme.border._200.opacity(theme.isDark ? 1 : 0.55)

        return HStack(alignment: .top, spacing: 0) {
            PracticeSummaryNumber(
                title: String(localized: "Correct"),
                value: "\(summary.correct)/\(summary.total)"
            )
            PracticeSummaryNumber(
                title: String(localized: "Time"),
                value: Self.clock(summary.activeSeconds)
            )
            PracticeSummaryNumber(
                title: String(localized: "Best combo"),
                value: "×\(summary.bestCombo)"
            )
        }
        .padding(.vertical, 16)
        .overlay(alignment: .top) {
            hairline.frame(height: 0.5)
        }
        .overlay(alignment: .bottom) {
            hairline.frame(height: 0.5)
        }
    }

    @ViewBuilder
    private var mistakes: some View {
        if summary.mistakes.isEmpty {
            Text("No mistakes in this pass.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.text.secondary)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("To review")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(theme.text.primary)
                    Spacer()
                    Text(summary.mistakes.count, format: .number)
                        .font(.system(size: 15, weight: .semibold).monospacedDigit())
                        .foregroundStyle(theme.text.secondary)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                    spacing: 10
                ) {
                    ForEach(summary.mistakes) { character in
                        PracticeMistakeChip(character: character)
                    }
                }
            }
        }
    }

    static func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let rest = total % 60
        return rest < 10 ? "\(minutes):0\(rest)" : "\(minutes):\(rest)"
    }
}

private struct PracticeSummaryNumber: View {
    let title: String
    let value: String

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .semibold).monospacedDigit())
                .foregroundStyle(theme.text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.text.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PracticeMistakeChip: View {
    let character: MojiCharacter

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: PracticeInteractionsStore { .shared }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        Button {
            interactions.speak(character)
        } label: {
            VStack(spacing: 2) {
                GlyphText(
                    text: character.glyph,
                    size: character.glyph.count > 2 ? 18 : 22,
                    color: theme.text.primary
                )
                Text(character.shortMeaning ?? character.romaji)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.text.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(shape.fill(theme.bg._300))
            .overlay(
                shape.strokeBorder(theme.border._200.opacity(theme.isDark ? 1 : 0.55), lineWidth: 1)
            )
            .contentShape(shape)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text(verbatim: "\(character.glyph), \(character.meaning ?? character.romaji)"))
    }
}
