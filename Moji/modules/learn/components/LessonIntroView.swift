import SwiftUI

struct LessonIntroView: View {
    let character: MojiCharacter

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: LearnInteractionsStore { .shared }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)

            LessonPromptTile(
                glyph: character.glyph,
                side: 210,
                showsSpeaker: true,
                action: { interactions.speak(character) }
            )
            .accessibilityLabel(Text("Play \(character.glyph)"))

            VStack(spacing: 6) {
                if let meaning = character.meaning {
                    Text(meaning)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(theme.text.primary)
                        .multilineTextAlignment(.center)
                    Text(character.readingLine)
                        .font(.system(size: 17, weight: .medium))
                        .typesettingLanguage(Locale.Language(identifier: "ja"))
                        .foregroundStyle(theme.text.secondary)
                    if let others = character.otherReadingsLine {
                        Text("Also: \(others)")
                            .font(.system(size: 14))
                            .typesettingLanguage(Locale.Language(identifier: "ja"))
                            .foregroundStyle(theme.text.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(character.romaji)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(theme.text.primary)
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
    }
}
