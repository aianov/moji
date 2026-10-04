import SwiftUI

struct LessonPage: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: LearnServicesStore { .shared }
    private var interactions: LearnInteractionsStore { .shared }

    var body: some View {
        let isExitAlertPresented = Binding(
            get: { service.isExitAlertPresented },
            set: { if !$0 { interactions.keepLearning() } }
        )

        ZStack {
            AppBackground()

            switch service.stage {
            case .loading:
                ProgressView()
                    .tint(theme.text.secondary)
            case .exercise(let model):
                VStack(spacing: 0) {
                    LessonTopBar(
                        progress: service.lessonProgress,
                        onClose: { interactions.close() }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    ZStack {
                        LessonExerciseView(model: model)
                            .id(model.id)
                            .transition(exerciseTransition)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .finished(let summary):
                LessonSummaryView(summary: summary)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            case .unavailable:
                LessonUnavailableView()
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: stageKey)
        .alert("Leave this lesson?", isPresented: isExitAlertPresented) {
            Button("Keep learning", role: .cancel) {
                interactions.keepLearning()
            }
            Button("Leave", role: .destructive) {
                interactions.leaveLesson()
            }
        } message: {
            Text("Answers you gave still count toward mastery. The lesson starts over next time.")
        }
    }

    private var exerciseTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var stageKey: String {
        switch service.stage {
        case .loading: "loading"
        case .exercise(let model): model.id
        case .finished: "finished"
        case .unavailable: "unavailable"
        }
    }
}

private struct LessonUnavailableView: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: LearnInteractionsStore { .shared }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(theme.text.secondary)
            Text("Couldn't start this lesson")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(theme.text.primary)
                .multilineTextAlignment(.center)
            Text("Close and try again.")
                .font(.system(size: 15))
                .foregroundStyle(theme.text.secondary)
            ProgressCapsuleButton(
                title: String(localized: "Close"),
                role: .secondary,
                action: { interactions.finish() }
            )
            .frame(maxWidth: 220)
            .padding(.top, 8)
        }
        .padding(32)
    }
}
