import SwiftUI

struct PracticeDrawingPrompt: View {
    let prompt: PracticePromptModel

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        VStack(spacing: 2) {
            Text(prompt.title)
                .font(.system(size: prompt.isMeaning ? 20 : 32, weight: .semibold))
                .foregroundStyle(theme.text.primary)
                .multilineTextAlignment(.center)
                .lineLimit(prompt.isMeaning ? 2 : 1)
                .minimumScaleFactor(0.6)
            if let subtitle = prompt.subtitle {
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .typesettingLanguage(Locale.Language(identifier: "ja"))
                    .foregroundStyle(theme.text.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(shape.fill(theme.bg._300))
        .overlay(
            shape
                .strokeBorder(theme.border._200.opacity(theme.isDark ? 1 : 0.55), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .accessibilityElement(children: .combine)
    }
}

struct PracticeDrawingStatusLine: View {
    let board: PracticeDrawingBoard

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        ZStack {
            if let failure = board.failure {
                VStack(spacing: 2) {
                    Text(failure.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MojiTint.wrong)
                    if let detail = failure.detail {
                        Text(detail)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(theme.text.secondary)
                    }
                }
                .transition(.opacity)
            } else if board.isPaused {
                Text("Finish the line from the dot")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.text.primary)
                    .transition(.opacity)
            } else if board.showsWholePhantom {
                Text("Trace over the outline")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.text.secondary)
                    .transition(.opacity)
            } else if board.showsCurrentStroke {
                Text("Go from point to point")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.text.secondary)
                    .transition(.opacity)
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .animation(.easeOut(duration: 0.2), value: board.failure)
        .animation(.easeOut(duration: 0.2), value: board.isPaused)
        .animation(.easeOut(duration: 0.2), value: board.showsWholePhantom)
        .animation(.easeOut(duration: 0.2), value: board.showsCurrentStroke)
    }
}

struct PracticeDrawingCanvas: View {
    let board: PracticeDrawingBoard
    let isAnswered: Bool

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: PracticeInteractionsStore { .shared }

    var body: some View {
        let showsHint = !isAnswered && board.canUseHint
        let isFirstHint = board.hint == .none

        WritingCanvas(source: board, onTouch: { interactions.handleDrawing($0, on: board) })
            .overlay(alignment: .bottomTrailing) {
                if showsHint {
                    Button {
                        interactions.useDrawingHint(on: board)
                    } label: {
                        Image(systemName: isFirstHint ? "lightbulb" : "lightbulb.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(theme.text.secondary)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(6)
                    .accessibilityLabel(isFirstHint ? Text("Show a hint") : Text("Show the whole character"))
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: showsHint)
    }
}
