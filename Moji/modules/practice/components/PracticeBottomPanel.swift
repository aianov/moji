import SwiftUI

struct PracticeBottomPanel: View {
    let model: PracticeQuestionModel
    let reveal: PracticeReveal?

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: PracticeServicesStore { .shared }
    private var interactions: PracticeInteractionsStore { .shared }

    static func height(for model: PracticeQuestionModel) -> CGFloat {
        model.answerLines.count > 1 ? 156 : 136
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let reveal {
                verdict(reveal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer(minLength: 0)

            actions
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .frame(height: Self.height(for: model))
        .background(alignment: .top) {
            if reveal != nil {
                theme.bg._300
                    .overlay(alignment: .top) {
                        theme.border._200
                            .opacity(theme.isDark ? 1 : 0.55)
                            .frame(height: 0.5)
                    }
                    .ignoresSafeArea(.container, edges: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: reveal)
    }

    @ViewBuilder
    private var actions: some View {
        if let reveal {
            ProgressCapsuleButton(
                title: String(localized: "Continue"),
                role: reveal.isCorrect ? .success : .error,
                action: { interactions.continueAfterReveal() }
            )
            .transition(.opacity)
        } else {
            HStack(spacing: 10) {
                LiquidGlassButton(
                    shape: .capsule,
                    size: 56,
                    action: { interactions.dontKnow() }
                ) {
                    Text("I don't know")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.text.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }

                ProgressCapsuleButton(
                    title: String(localized: "Check"),
                    role: .primary,
                    action: { interactions.check() }
                )
                .disabled(model.isTyped ? !service.canSubmitTypedAnswer : service.selectedOptionID == nil)
            }
            .transition(.opacity)
        }
    }

    private func verdict(_ reveal: PracticeReveal) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label {
                Text(title(for: reveal))
            } icon: {
                Image(systemName: reveal.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .symbolEffect(.bounce, value: reveal.isCorrect)
            }
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(color(for: reveal))

            if !reveal.isCorrect || model.isTyped {
                let lines = model.answerLines(typed: reveal.isCorrect ? reveal.typed : nil)
                Text(lines[0])
                    .font(.system(size: 16, weight: .semibold))
                    .typesettingLanguage(Locale.Language(identifier: "ja"))
                    .foregroundStyle(theme.text.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if lines.count > 1 {
                    Text(lines[1])
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(theme.text.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func title(for reveal: PracticeReveal) -> String {
        if reveal.isCorrect {
            let streak = model.combo + 1
            return streak >= 5 ? String(localized: "Correct! ×\(streak)") : String(localized: "Correct!")
        }
        if reveal.chosenID == nil, reveal.typed == nil {
            return String(localized: "Here's the answer")
        }
        return String(localized: "Not quite")
    }

    private func color(for reveal: PracticeReveal) -> Color {
        reveal.isCorrect ? MojiTint.correct : MojiTint.wrong
    }
}
