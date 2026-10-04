import SwiftUI

struct LessonWordView: View {
    let characters: [MojiCharacter]
    let options: [[MojiCharacter]]?

    private var service: LearnServicesStore { .shared }
    private var interactions: LearnInteractionsStore { .shared }

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 8)
            LessonSoundButton(side: 112, action: { interactions.replay() })
            Spacer(minLength: 8)

            if let options {
                VStack(spacing: 10) {
                    ForEach(options.indices, id: \.self) { index in
                        LessonOptionTile(
                            title: options[index].map(\.glyph).joined(),
                            isGlyph: true,
                            state: state(for: index, options: options),
                            height: 62,
                            detail: Self.detail(for: options[index]),
                            action: { interactions.chooseWord(index) }
                        )
                    }
                }
                .padding(.horizontal, 20)
            } else {
                LessonAnswerField(placeholderIsReading: false)
                    .padding(.horizontal, 20)
            }
        }
    }

    private static func detail(for characters: [MojiCharacter]) -> String {
        if characters.contains(where: { $0.script.isKanji }) {
            return characters.map { character in
                character.shortMeaning.map { "\(character.romaji) \($0)" } ?? character.romaji
            }
            .joined(separator: " · ")
        }
        return characters.map(\.romaji).joined()
    }

    private func state(for index: Int, options: [[MojiCharacter]]) -> LessonOptionState {
        guard service.feedback != nil else {
            return index == service.chosenWordIndex ? .selected : .idle
        }
        if options[index].map(\.id) == characters.map(\.id) { return .correct }
        if index == service.chosenWordIndex { return .wrong }
        return .dimmed
    }
}

struct LessonReadView: View {
    let characters: [MojiCharacter]

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: LearnServicesStore { .shared }
    private var interactions: LearnInteractionsStore { .shared }

    var body: some View {
        let answered = service.feedback != nil

        VStack(spacing: 18) {
            Spacer(minLength: 8)
            LessonPromptTile(
                glyph: characters.map(\.glyph).joined(),
                side: 190,
                showsSpeaker: answered,
                action: answered ? { interactions.replay() } : nil
            )
            Spacer(minLength: 8)
            LessonAnswerField(placeholderIsReading: characters.first?.script.isKanji ?? false)
                .padding(.horizontal, 20)
        }
    }
}

struct LessonAnswerField: View {
    let placeholderIsReading: Bool

    @FocusState private var isFocused: Bool

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: LearnServicesStore { .shared }
    private var interactions: LearnInteractionsStore { .shared }

    var body: some View {
        let text = Binding(
            get: { service.typedText },
            set: { interactions.setTypedText($0) }
        )
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        Group {
            if placeholderIsReading {
                TextField("Reading in romaji", text: text)
            } else {
                TextField("Type in romaji", text: text)
            }
        }
        .font(.system(size: 22, weight: .medium))
        .foregroundStyle(textColor)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .keyboardType(.asciiCapable)
        .submitLabel(.done)
        .onSubmit { interactions.submitTyped() }
        .focused($isFocused)
        .disabled(service.feedback != nil)
        .padding(.leading, 18)
        .padding(.trailing, 44)
        .frame(height: 58)
        .background(shape.fill(theme.bg._300))
        .overlay(shape.strokeBorder(borderColor, lineWidth: service.feedback == nil ? 1 : 1.5))
        .overlay(alignment: .trailing) {
            if service.feedback == nil {
                Button {
                    interactions.useHint()
                } label: {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.text.secondary)
                        .frame(width: 44, height: 58)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(Text("Show the answer"))
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: service.feedback == nil)
        .onAppear { isFocused = true }
    }

    private var textColor: Color {
        guard let feedback = service.feedback else { return theme.text.primary }
        return feedback.isCorrect ? MojiTint.correct : MojiTint.wrong
    }

    private var borderColor: Color {
        guard let feedback = service.feedback else {
            return isFocused ? theme.text.primary.opacity(0.6) : theme.border._200.opacity(theme.isDark ? 1 : 0.6)
        }
        return feedback.isCorrect ? MojiTint.correct : MojiTint.wrong
    }
}
