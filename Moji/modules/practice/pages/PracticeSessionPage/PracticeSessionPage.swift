import SwiftUI

struct PracticeSessionPage: View {
    let page: MojiPage

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: PracticeServicesStore { .shared }
    private var interactions: PracticeInteractionsStore { .shared }

    var body: some View {
        let isExitSheetPresented = Binding(
            get: { service.isExitSheetPresented },
            set: { if !$0 { interactions.keepPracticing() } }
        )

        ZStack {
            AppBackground()

            switch service.stage {
            case .loading:
                ProgressView()
                    .tint(theme.text.secondary)
            case .question, .revealed:
                if let model = service.currentQuestion {
                    let reveal = service.currentReveal

                    VStack(spacing: 0) {
                        PracticeTopBar(
                            answered: model.answeredCount(after: reveal),
                            total: model.total,
                            combo: model.combo(after: reveal),
                            onClose: { interactions.close() }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .contentShape(Rectangle())
                        .onTapGesture { interactions.dismissKeyboard() }

                        PracticeQuestionView(model: model, reveal: reveal)
                    }
                }
            case .finished(let summary):
                PracticeSummaryView(summary: summary)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            case .unavailable:
                PracticeUnavailableView()
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: stageKey)
        .sheet(isPresented: isExitSheetPresented, onDismiss: { interactions.exitSheetDidDismiss() }) {
            PracticeExitSheet(page: page)
                .themedPresentation()
        }
    }

    private var stageKey: String {
        switch service.stage {
        case .loading: "loading"
        case .question(let model), .revealed(let model, _): model.id
        case .finished: "finished"
        case .unavailable: "unavailable"
        }
    }
}

private struct PracticeUnavailableView: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: PracticeInteractionsStore { .shared }

    var body: some View {
        VStack(spacing: 12) {
            Text("Couldn't start this session")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(theme.text.primary)
                .multilineTextAlignment(.center)
            Text("Close and try again.")
                .font(.system(size: 15))
                .foregroundStyle(theme.text.secondary)
                .multilineTextAlignment(.center)
            LiquidGlassButton(
                shape: .capsule,
                size: 48,
                horizontalPadding: 28,
                action: { interactions.finish() }
            ) {
                Text("Close")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.text.primary)
            }
            .padding(.top, 12)
        }
        .padding(32)
    }
}
