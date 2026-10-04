import SwiftUI

struct LessonSummaryView: View {
    let summary: LessonSummaryModel

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: LearnInteractionsStore { .shared }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header

                HStack(spacing: 12) {
                    LessonStatTile(
                        title: String(localized: "Accuracy"),
                        value: "\(Int((summary.accuracy * 100).rounded()))%"
                    )
                    LessonStatTile(
                        title: String(localized: "Answers"),
                        value: "\(summary.correct)/\(summary.answered)"
                    )
                    if summary.hardDone > 0 {
                        LessonStatTile(
                            title: String(localized: "Hard exercises"),
                            value: "\(summary.hardDone)"
                        )
                    }
                }

                nextStep

                if !summary.characters.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("In this lesson")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(theme.text.primary)

                        if summary.page.isKanji {
                            LearnKanjiGrid(maximumColumns: 4, spacing: 10, rowSpacing: 10) {
                                ForEach(summary.characters) { entry in
                                    LessonSummaryChip(entry: entry)
                                }
                            }
                        } else {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                                spacing: 10
                            ) {
                                ForEach(summary.characters) { entry in
                                    LessonSummaryChip(entry: entry)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
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
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(theme.text.primary)

            Group {
                if summary.isReview {
                    Text("Review complete")
                } else {
                    Text("Lesson complete")
                }
            }
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(theme.text.primary)

            Group {
                if let number = summary.batchNumber {
                    Text("\(summary.page.fullTitle) · batch \(number) of \(summary.batchCount)")
                } else {
                    Text(summary.page.fullTitle)
                }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(theme.text.secondary)

            if let streakDay = summary.streakDay {
                Label {
                    Group {
                        if streakDay <= 1 {
                            Text("Streak started: day 1")
                        } else {
                            Text("Day \(streakDay) of your streak")
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

    @ViewBuilder
    private var nextStep: some View {
        switch summary.next {
        case .batch(let number, let characters):
            VStack(alignment: .leading, spacing: 10) {
                Label("Up next: batch \(number)", systemImage: "arrow.forward.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.text.primary)
                if summary.page.isKanji {
                    LearnKanjiGrid(spacing: 8, rowSpacing: 10) {
                        ForEach(characters) { character in
                            LessonNextCell(character: character)
                        }
                    }
                } else {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(characters) { character in
                            LessonNextCell(character: character)
                                .frame(maxWidth: 56)
                        }
                    }
                }
            }
            .lessonCard()
        case .sameBatch:
            Label("The next lesson goes over these characters once more.", systemImage: "arrow.counterclockwise.circle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lessonCard()
        case .allLearned:
            EmptyView()
        }
    }
}

private struct LessonNextCell: View {
    let character: MojiCharacter

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        VStack(spacing: 2) {
            GlyphText(
                text: character.glyph,
                size: 26,
                color: theme.text.primary
            )
            Text(character.romaji)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.text.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .allowsTightening(true)
            if let meaning = character.shortMeaning {
                LearnMeaningText(meaning: meaning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private struct LessonStatTile: View {
    let title: String
    let value: String

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 24, weight: .bold).monospacedDigit())
                .foregroundStyle(theme.text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.text.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(theme.bg._300))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(theme.border._200.opacity(theme.isDark ? 1 : 0.6), lineWidth: 1)
        )
    }
}

private struct LessonSummaryChip: View {
    let entry: LessonSummaryCharacter

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: LearnInteractionsStore { .shared }

    var body: some View {
        let mastery = Double(min(entry.strength, MojiCharacterProgress.masteryLevel))
            / Double(MojiCharacterProgress.masteryLevel)
        let meaning = entry.character.shortMeaning

        Button {
            interactions.speak(entry.character)
        } label: {
            VStack(spacing: 4) {
                GlyphText(
                    text: entry.character.glyph,
                    size: entry.character.glyph.count > 1 ? 18 : 24,
                    color: theme.text.primary
                )
                Text(entry.character.romaji)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.text.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)
                    .padding(.horizontal, 4)
                if let meaning {
                    LearnMeaningText(meaning: meaning)
                        .padding(.horizontal, 4)
                    Spacer(minLength: 0)
                }
                ProgressBarUi(
                    progress: mastery,
                    height: 4,
                    track: theme.bg._600,
                    fill: MojiTint.gold
                )
                .padding(.horizontal, 8)
                .padding(.top, 2)
            }
            .padding(.vertical, meaning == nil ? 0 : 10)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 80, maxHeight: meaning == nil ? 80 : .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.bg._300))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        entry.isNew ? theme.text.primary.opacity(0.5) : theme.border._200.opacity(theme.isDark ? 1 : 0.6),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text("\(entry.character.glyph), strength \(entry.strength) of \(MojiCharacterProgress.masteryLevel)"))
    }
}

private extension View {
    @MainActor
    func lessonCard() -> some View {
        let theme = ThemeStore.shared.currentTheme
        return self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(theme.bg._300))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(theme.border._200.opacity(theme.isDark ? 1 : 0.6), lineWidth: 1)
            )
    }
}
