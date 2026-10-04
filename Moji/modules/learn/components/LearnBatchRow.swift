import SwiftUI

struct LearnBatchRow: View {
    let state: MojiLearnBatchState

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: LearnServicesStore { .shared }
    private var interactions: LearnInteractionsStore { .shared }
    private var search: SearchServicesStore { .shared }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let characters = state.batch.characterIDs.compactMap { service.character($0) }
        let number = state.batch.index + 1

        HStack(spacing: 12) {
            Button {
                interactions.startLesson(state.batch.page, batchIndex: state.batch.index)
            } label: {
                LearnBatchBadge(status: state.status, number: number)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!service.isLoaded)
            .accessibilityLabel(Text("Start a lesson on batch \(number)"))

            Group {
                if state.batch.page.isKanji {
                    LearnKanjiGrid {
                        cells(characters)
                    }
                } else {
                    HStack(spacing: 4) {
                        cells(characters)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .fixedSize(horizontal: false, vertical: true)
        .background(shape.fill(theme.bg._300))
        .overlay(
            shape.strokeBorder(
                state.status == .current ? theme.text.primary.opacity(0.85) : theme.border._200.opacity(theme.isDark ? 1 : 0.55),
                lineWidth: state.status == .current ? 1.5 : 1
            )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(accessibilityText(characters)))
    }

    private func cells(_ characters: [MojiCharacter]) -> some View {
        let found = search.learn

        return ForEach(characters) { character in
            Button {
                interactions.openCharacter(character)
            } label: {
                LearnGlyphCell(
                    character: character,
                    strength: service.strength(of: character.id),
                    mark: found.mark(character.id, in: state.batch.page.script)
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func accessibilityText(_ characters: [MojiCharacter]) -> String {
        let glyphs = characters.map(\.glyph).joined(separator: " ")
        let number = state.batch.index + 1
        switch state.status {
        case .learned: return String(localized: "Batch \(number), learned: \(glyphs)")
        case .current: return String(localized: "Batch \(number), current: \(glyphs)")
        case .review: return String(localized: "Batch \(number), needs review: \(glyphs)")
        case .new: return String(localized: "Batch \(number), not started: \(glyphs)")
        }
    }
}

struct LearnBatchBadge: View {
    let status: MojiLearnBatchStatus
    let number: Int

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        ZStack {
            Circle()
                .fill(fill)
            switch status {
            case .learned:
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MojiTint.gold)
            case .current:
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.bg._100)
                    .offset(x: 1)
            case .review:
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.text.secondary)
            case .new:
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(theme.text.secondary)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }

    private var fill: Color {
        switch status {
        case .learned: MojiTint.gold.opacity(theme.isDark ? 0.18 : 0.16)
        case .current: theme.text.primary
        case .review, .new: theme.bg._500
        }
    }
}

struct LearnGlyphCell: View {
    let character: MojiCharacter
    let strength: Int
    var mark: CharacterSearchMark = .unmatched

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let mastery = Double(min(strength, MojiCharacterProgress.masteryLevel)) / Double(MojiCharacterProgress.masteryLevel)
        let meaning = character.shortMeaning

        VStack(spacing: 3) {
            GlyphText(
                text: character.glyph,
                size: character.glyph.count > 1 ? 17 : 23,
                color: theme.text.primary
            )
            .frame(height: 28)

            Text(character.romaji)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.text.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .allowsTightening(true)
                .padding(.horizontal, 2)

            if let meaning {
                LearnMeaningText(meaning: meaning)
                    .padding(.horizontal, 2)
                Spacer(minLength: 0)
            }

            ProgressBarUi(
                progress: mastery,
                height: 4,
                track: theme.bg._600,
                fill: MojiTint.gold
            )
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: meaning == nil ? nil : .infinity)
        .padding(.vertical, 5)
        .characterSearchMark(mark, cornerRadius: 12)
        .contentShape(Rectangle())
    }
}
