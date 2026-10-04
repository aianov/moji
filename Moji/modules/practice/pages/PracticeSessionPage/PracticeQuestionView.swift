import SwiftUI

struct PracticeQuestionView: View {
    let model: PracticeQuestionModel
    let reveal: PracticeReveal?
    var board: PracticeDrawingBoard? = nil

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: PracticeInteractionsStore { .shared }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                content
                    .id(model.id)
                    .transition(contentTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if model.isTyped {
                PracticeAnswerField(model: model, reveal: reveal)
                    .padding(.horizontal, 20)
                    .transition(.opacity)
            }

            PracticeBottomPanel(
                model: model,
                reveal: reveal
            )
            .padding(.top, 12)
            .contentShape(Rectangle())
            .onTapGesture { interactions.dismissKeyboard() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isDrawn {
            drawingContent
        } else {
            answerContent
                .contentShape(Rectangle())
                .onTapGesture { interactions.dismissKeyboard() }
        }
    }

    private var instruction: some View {
        Text(model.instruction)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(theme.text.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 14)
    }

    private var answerContent: some View {
        VStack(spacing: 0) {
            instruction
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            promptCard

            if model.answerStyle == .choice {
                VStack(spacing: 10) {
                    ForEach(model.options) { option in
                        PracticeOptionButton(
                            option: option,
                            state: state(for: option),
                            action: { interactions.select(option.id) }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var drawingContent: some View {
        VStack(spacing: 0) {
            instruction
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            PracticeDrawingPrompt(prompt: model.prompt)
                .padding(.horizontal, 20)
                .padding(.top, 12)

            if let board, board.questionID == model.id {
                PracticeDrawingStatusLine(board: board)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                PracticeDrawingCanvas(board: board, isAnswered: reveal != nil)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(x: 28)),
            removal: .opacity.combined(with: .offset(x: -28))
        )
    }

    @ViewBuilder
    private var promptCard: some View {
        let card = PracticePromptCard(
            model: model,
            onSpeak: { interactions.speakPrompt() }
        )

        switch model.answerStyle {
        case .choice:
            card
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 250, maxHeight: 250)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .romaji, .character, .drawing:
            card
                .frame(maxWidth: .infinity, minHeight: 72, maxHeight: 220)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxHeight: .infinity)
        }
    }

    private func state(for option: PracticeOptionModel) -> PracticeOptionState {
        guard let reveal else {
            return option.id == PracticeServicesStore.shared.selectedOptionID ? .selected : .idle
        }
        if option.id == model.correctOptionID {
            return .correct
        }
        if option.id == reveal.chosenID {
            return .wrong
        }
        return .dimmed
    }
}
