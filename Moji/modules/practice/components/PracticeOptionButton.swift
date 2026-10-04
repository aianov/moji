import SwiftUI

enum PracticeOptionState: Equatable {
    case idle
    case selected
    case correct
    case wrong
    case dimmed

    var isRevealed: Bool {
        switch self {
        case .correct, .wrong, .dimmed: true
        case .idle, .selected: false
        }
    }
}

struct PracticeOptionButton: View {
    let option: PracticeOptionModel
    let state: PracticeOptionState
    let action: () -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        Button(action: action) {
            HStack(spacing: 12) {
                Color.clear
                    .frame(width: 22, height: 22)

                VStack(spacing: 1) {
                    if option.isGlyph {
                        GlyphText(
                            text: option.title,
                            size: option.title.count > 2 ? 24 : 30,
                            color: titleColor
                        )
                    } else {
                        Text(option.title)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(titleColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    if let subtitle = option.subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .typesettingLanguage(Locale.Language(identifier: "ja"))
                            .foregroundStyle(subtitleColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    if state.isRevealed, let detail = option.detail {
                        Group {
                            if option.detailIsGlyph {
                                GlyphText(text: detail, size: 20, color: subtitleColor)
                            } else {
                                Text(detail)
                                    .font(.system(size: 13, weight: .medium))
                                    .typesettingLanguage(Locale.Language(identifier: "ja"))
                                    .foregroundStyle(subtitleColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxWidth: .infinity)

                ZStack {
                    switch state {
                    case .correct:
                        Image(systemName: "checkmark")
                            .transition(.scale.combined(with: .opacity))
                    case .wrong:
                        Image(systemName: "xmark")
                            .transition(.scale.combined(with: .opacity))
                    case .idle, .selected, .dimmed:
                        EmptyView()
                    }
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 22, height: 22)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .frame(minHeight: option.subtitle == nil ? 56 : 62)
            .background(shape.fill(fill))
            .overlay(
                shape
                    .strokeBorder(border, lineWidth: state == .selected ? 2 : 1)
                    .allowsHitTesting(false)
            )
            .contentShape(shape)
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.98))
        .allowsHitTesting(!state.isRevealed)
        .opacity(state == .dimmed ? 0.6 : 1)
        .scaleEffect(state == .selected ? 1.015 : 1)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: state)
        .modifier(ShakeEffect(progress: state == .wrong ? 1 : 0))
        .animation(.linear(duration: 0.4), value: state)
        .accessibilityAddTraits(state == .correct || state == .selected ? [.isButton, .isSelected] : .isButton)
    }

    private var fill: Color {
        switch state {
        case .correct: MojiTint.correct
        case .wrong: MojiTint.wrong
        case .idle, .selected, .dimmed: theme.bg._300
        }
    }

    private var border: Color {
        switch state {
        case .correct, .wrong: .clear
        case .selected: theme.text.primary
        case .idle, .dimmed: theme.border._200.opacity(theme.isDark ? 1 : 0.55)
        }
    }

    private var titleColor: Color {
        switch state {
        case .correct, .wrong: .white
        case .idle, .selected: theme.text.primary
        case .dimmed: theme.text.secondary
        }
    }

    private var subtitleColor: Color {
        switch state {
        case .correct, .wrong: Color.white.opacity(0.85)
        case .idle, .selected, .dimmed: theme.text.secondary
        }
    }
}

struct ShakeEffect: GeometryEffect {
    var progress: CGFloat
    var travel: CGFloat = 7
    var swings: CGFloat = 3

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = travel * sin(progress * .pi * 2 * swings)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}
