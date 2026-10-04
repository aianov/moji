import SwiftUI

struct CharacterSectionHeader: View {
    let section: MojiCharacterSection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = section.title {
                MainText(text: title, px: 22, fontWeight: .bold)
            }
            if let subtitle = section.subtitle {
                SecondaryText(text: subtitle, px: 15)
            }
        }
    }
}

struct CharacterSectionRow: View {
    let row: MojiCharacterRow
    let columns: Int
    let script: MojiScript

    private var practice: PracticeServicesStore { .shared }
    private var interactions: AlphabetInteractionsStore { .shared }
    private var search: SearchServicesStore { .shared }

    var body: some View {
        let found = search.practice
        let height = CharacterCell.height(for: script)

        HStack(spacing: 10) {
            ForEach(row.slots) { slot in
                switch slot {
                case .character(let character):
                    CharacterCell(
                        character: character,
                        progress: practice.progress(for: character.id),
                        mark: found.mark(character.id, in: script),
                        action: { interactions.openCharacter(character) }
                    )
                case .gap:
                    CharacterGapCell(height: height)
                }
            }

            ForEach(row.slots.count..<max(columns, row.slots.count), id: \.self) { _ in
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .accessibilityHidden(true)
            }
        }
    }
}

struct CharacterCell: View {
    let character: MojiCharacter
    let progress: MojiCharacterProgress?
    var mark: CharacterSearchMark = .unmatched
    let action: () -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    static func height(for script: MojiScript) -> CGFloat {
        script.isKanji ? 98 : 80
    }

    private var glyphSize: CGFloat {
        switch character.glyph.count {
        case 1: character.script.isKanji ? 30 : 26
        case 2: 24
        default: 22
        }
    }

    var body: some View {
        let isMastered = progress?.isMastered ?? false
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        Button(action: action) {
            VStack(spacing: 2) {
                GlyphText(
                    text: character.glyph,
                    size: glyphSize,
                    color: isMastered ? MojiTint.gold : theme.text.primary
                )
                if let meaning = character.shortMeaning {
                    Text(meaning)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(isMastered ? MojiTint.gold.opacity(0.9) : theme.text.primary.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(character.romaji)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.text.secondary.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text(character.romaji)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isMastered ? MojiTint.gold.opacity(0.85) : theme.text.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                ProgressBarUi(
                    progress: progress?.mastery ?? 0,
                    height: 5,
                    track: theme.bg._600,
                    fill: MojiTint.gold
                )
                .padding(.horizontal, 10)
            }
            .padding(.top, 9)
            .padding(.bottom, 10)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .frame(height: Self.height(for: character.script))
            .background {
                shape
                    .fill(theme.bg._300)
                    .overlay(shape.fill(mark.fill(theme)))
            }
            .overlay(
                shape.strokeBorder(borderColor(isMastered: isMastered), lineWidth: borderWidth(isMastered: isMastered))
            )
            .contentShape(shape)
            .animation(.easeOut(duration: 0.2), value: mark)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text(accessibilityText))
    }

    private func borderColor(isMastered: Bool) -> Color {
        if mark.isFound {
            return mark.border(theme)
        }
        return isMastered
            ? MojiTint.gold.opacity(0.75)
            : theme.border._200.opacity(theme.isDark ? 1 : 0.55)
    }

    private func borderWidth(isMastered: Bool) -> CGFloat {
        if mark.isFound {
            return mark.borderWidth
        }
        return isMastered ? 1.5 : 1
    }

    private var accessibilityText: String {
        let glyph = character.glyph
        let romaji = character.romaji
        let isMastered = progress?.isMastered == true
        if let meaning = character.meaning {
            return isMastered
                ? String(localized: "\(glyph), \(romaji), \(meaning), mastered")
                : "\(glyph), \(romaji), \(meaning)"
        }
        return isMastered
            ? String(localized: "\(glyph), \(romaji), mastered")
            : "\(glyph), \(romaji)"
    }
}

struct CharacterGapCell: View {
    let height: CGFloat

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(theme.bg._200.opacity(theme.isDark ? 1 : 0.7))
            .frame(height: height)
            .accessibilityHidden(true)
    }
}
