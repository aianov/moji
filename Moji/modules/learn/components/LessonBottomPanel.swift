import SwiftUI

struct LessonBottomPanel: View {
    let model: LessonExerciseModel

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: LearnServicesStore { .shared }
    private var interactions: LearnInteractionsStore { .shared }

    var body: some View {
        let feedback = service.feedback

        VStack(alignment: .leading, spacing: 12) {
            if let feedback {
                verdict(feedback)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                ProgressCapsuleButton(
                    title: String(localized: "Continue"),
                    role: feedback.isCorrect ? .success : .error,
                    action: { interactions.continueLesson() }
                )
            } else {
                controls
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .bottom)
        .background(alignment: .top) {
            if feedback != nil {
                UnevenRoundedRectangle(
                    topLeadingRadius: 26,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 26,
                    style: .continuous
                )
                .fill(theme.bg._300)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(theme.border._200.opacity(theme.isDark ? 1 : 0.6))
                        .frame(height: 1)
                        .padding(.horizontal, 26)
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: feedback)
    }

    @ViewBuilder
    private var controls: some View {
        switch model.content {
        case .intro:
            ProgressCapsuleButton(
                title: String(localized: "Continue"),
                role: .primary,
                action: { interactions.continueLesson() }
            )
        case .word(_, .none), .read:
            let isEmpty = MojiLearnGrading.normalizedRomaji(service.typedText).isEmpty
            ProgressCapsuleButton(
                title: String(localized: "Check"),
                role: .primary,
                action: { interactions.check() }
            )
            .disabled(isEmpty)
        case .choice, .listen:
            ProgressCapsuleButton(
                title: String(localized: "Check"),
                role: .primary,
                action: { interactions.check() }
            )
            .disabled(service.chosenOptionID == nil)
        case .word:
            ProgressCapsuleButton(
                title: String(localized: "Check"),
                role: .primary,
                action: { interactions.check() }
            )
            .disabled(service.chosenWordIndex == nil)
        case .match:
            EmptyView()
        }
    }

    private func verdict(_ feedback: LessonFeedback) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: feedback.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 28, weight: .bold))

            VStack(alignment: .leading, spacing: 2) {
                Text(feedback.title)
                    .font(.system(size: 20, weight: .bold))
                if let detail = feedback.detail {
                    Text(detail)
                        .font(.system(size: 15, weight: .semibold))
                        .typesettingLanguage(Locale.Language(identifier: "ja"))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(feedback.isCorrect ? MojiTint.correct : MojiTint.wrong)
    }
}
