import SwiftUI

struct PracticeLaunchBar: View {
    let page: MojiPage

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var practice: PracticeServicesStore { .shared }
    private var interactions: PracticeInteractionsStore { .shared }

    var body: some View {
        let state = practice.launchState(for: page)
        let isModeSheetPresented = Binding(
            get: { practice.answerModePage == page },
            set: { if !$0 { interactions.closeAnswerMode() } }
        )

        VStack(spacing: 10) {
            HStack(spacing: 10) {
                CharacterSearchField(surface: .practice, script: page.script)

                PracticeAnswerModeButton(
                    script: page.script,
                    mode: practice.answerMode(for: page),
                    action: { interactions.openAnswerMode(page) }
                )
            }

            HStack(spacing: 10) {
                cta(state: state)

                if case .inProgress = state {
                    LiquidGlassButton(
                        shape: .circle,
                        size: 56,
                        accessibilityLabel: String(localized: "Discard session"),
                        action: { interactions.requestDiscard(page) }
                    ) {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(theme.text.secondary)
                    }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: state)
        .sheet(isPresented: isModeSheetPresented) {
            PracticeAnswerModeSheet(page: page)
                .themedPresentation()
        }
    }

    @ViewBuilder
    private func cta(state: PracticeLaunchState) -> some View {
        switch state {
        case .fresh:
            ProgressCapsuleButton(
                title: String(localized: "Start practice"),
                systemImage: "play.fill",
                role: .primary,
                action: { interactions.openPractice(page) }
            )
        case let .inProgress(answered, total, _):
            ProgressCapsuleButton(
                title: String(localized: "Continue"),
                detail: "\(answered)/\(total)",
                progress: total > 0 ? Double(answered) / Double(total) : 0,
                role: .primary,
                action: { interactions.openPractice(page) }
            )
        case .doneToday:
            ProgressCapsuleButton(
                title: String(localized: "Practice again"),
                systemImage: "arrow.counterclockwise",
                role: .primary,
                action: { interactions.openPractice(page) }
            )
        }
    }
}

private struct PracticeAnswerModeButton: View {
    let script: MojiScript
    let mode: MojiAnswerMode
    let action: () -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        LiquidGlassButton(
            shape: .capsule,
            size: CharacterSearchField.height,
            horizontalPadding: 14,
            accessibilityLabel: String(
                localized: "Answer mode: \(mode.input.title), \(mode.side.title(for: script))"
            ),
            action: action
        ) {
            HStack(spacing: 6) {
                Image(systemName: mode.input.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(verbatim: mode.side.arrow(for: script))
                    .font(.system(size: 14, weight: .semibold))
                    .typesettingLanguage(Locale.Language(identifier: "ja"))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.text.secondary)
            }
            .foregroundStyle(theme.text.primary)
        }
        .fixedSize()
    }
}
