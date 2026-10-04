import SwiftUI

struct LessonChoiceView: View {
    let prompt: MojiCharacter
    let direction: MojiLessonDirection
    let options: [MojiCharacter]

    private var service: LearnServicesStore { .shared }
    private var interactions: LearnInteractionsStore { .shared }

    var body: some View {
        let answered = service.feedback != nil

        VStack(spacing: 0) {
            Spacer(minLength: 8)

            switch direction {
            case .glyphToAnswer:
                LessonPromptTile(
                    glyph: prompt.glyph,
                    showsSpeaker: answered,
                    action: answered ? { interactions.replay() } : nil
                )
            case .answerToGlyph:
                LessonPromptTile(
                    title: prompt.meaning ?? prompt.romaji,
                    subtitle: prompt.meaning == nil ? nil : prompt.readingLine
                )
            }

            Spacer(minLength: 8)

            LessonOptionGrid(
                options: options,
                answerID: prompt.id,
                showsGlyphs: direction == .answerToGlyph
            )
            .padding(.horizontal, 20)
        }
    }
}

struct LessonListenView: View {
    let answer: MojiCharacter
    let options: [MojiCharacter]

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: LearnInteractionsStore { .shared }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            LessonSoundButton(side: 128, action: { interactions.replay() })
            Spacer(minLength: 8)
            LessonOptionGrid(options: options, answerID: answer.id, showsGlyphs: true)
                .padding(.horizontal, 20)
        }
    }
}

struct LessonOptionGrid: View {
    let options: [MojiCharacter]
    let answerID: String
    let showsGlyphs: Bool

    private var service: LearnServicesStore { .shared }
    private var interactions: LearnInteractionsStore { .shared }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(options) { option in
                if showsGlyphs {
                    LessonOptionTile(
                        title: option.glyph,
                        isGlyph: true,
                        state: state(for: option.id),
                        detail: option.optionDetailLine,
                        action: { interactions.choose(option.id) }
                    )
                } else {
                    LessonOptionTile(
                        title: option.meaning ?? option.romaji,
                        subtitle: option.meaning == nil ? nil : option.readingLine,
                        isGlyph: false,
                        state: state(for: option.id),
                        detail: option.glyph,
                        detailIsGlyph: true,
                        action: { interactions.choose(option.id) }
                    )
                }
            }
        }
    }

    private func state(for id: String) -> LessonOptionState {
        guard service.feedback != nil else {
            return id == service.chosenOptionID ? .selected : .idle
        }
        if id == answerID { return .correct }
        if id == service.chosenOptionID { return .wrong }
        return .dimmed
    }
}

struct LessonSoundButton: View {
    var side: CGFloat = 112
    let action: () -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        Button(action: action) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: side * 0.27, weight: .semibold))
                .foregroundStyle(theme.text.primary)
                .frame(width: side, height: side)
                .background(Circle().fill(theme.bg._300))
                .overlay(Circle().strokeBorder(theme.border._200.opacity(theme.isDark ? 1 : 0.6), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text("Play the sound"))
    }
}
