import SwiftUI

struct LessonExerciseView: View {
    let model: LessonExerciseModel

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: LearnServicesStore { .shared }

    private var showsBottomPanel: Bool {
        model.kind != .write || service.feedback != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                if model.isHard {
                    LessonTag(text: String(localized: "Hard exercise"), systemImage: "dial.high")
                } else if model.isRetry {
                    LessonTag(text: String(localized: "Previous mistake"), systemImage: "arrow.counterclockwise")
                }
                instruction
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(theme.text.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 14)

            Group {
                switch model.content {
                case .intro(let character):
                    LessonIntroView(character: character)
                case .choice(let prompt, let direction, let options):
                    LessonChoiceView(prompt: prompt, direction: direction, options: options)
                case .listen(let answer, let options):
                    LessonListenView(answer: answer, options: options)
                case .match(let left, let right):
                    LessonMatchView(left: left, right: right)
                case .write:
                    LessonWriteView(model: model)
                case .word(let characters, let options):
                    LessonWordView(characters: characters, options: options)
                case .read(let characters):
                    LessonReadView(characters: characters)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showsBottomPanel {
                LessonBottomPanel(model: model)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: showsBottomPanel)
    }

    private var instruction: Text {
        let isKanji = model.page.isKanji
        switch model.content {
        case .intro:
            return isKanji ? Text("New kanji") : Text("New character")
        case .choice(_, .glyphToAnswer, _):
            return isKanji ? Text("What does this kanji mean?") : Text("What sound does this make?")
        case .choice(_, .answerToGlyph, _):
            return isKanji ? Text("Which kanji means this?") : Text("Which character makes this sound?")
        case .listen:
            return isKanji ? Text("Which kanji do you hear?") : Text("Which character do you hear?")
        case .match:
            return Text("Match the pairs")
        case .write(let characters) where characters.count == 1:
            return isKanji ? Text("Write this kanji") : Text("Write this character")
        case .write:
            return isKanji ? Text("Write these kanji") : Text("Write these characters")
        case .word(_, .none):
            return Text("Type what you hear")
        case .word(_, .some):
            return Text("Pick what you hear")
        case .read:
            return isKanji ? Text("Type this kanji's reading") : Text("Type how this reads")
        }
    }
}

struct LessonTag: View {
    let text: String
    let systemImage: String

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(theme.text.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(theme.bg._300))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(theme.border._200.opacity(theme.isDark ? 1 : 0.6), lineWidth: 1)
        )
    }
}
