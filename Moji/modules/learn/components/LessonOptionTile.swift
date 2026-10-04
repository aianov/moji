import SwiftUI

enum LessonOptionState: Equatable {
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

struct LessonOptionTile: View {
    let title: String
    var subtitle: String? = nil
    let isGlyph: Bool
    let state: LessonOptionState
    var height: CGFloat = 84
    var detail: String? = nil
    var detailIsGlyph = false
    let action: () -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        Button(action: action) {
            VStack(spacing: 3) {
                if isGlyph {
                    GlyphText(
                        text: title,
                        size: title.count > 2 ? 26 : 34,
                        color: titleColor
                    )
                } else {
                    Text(title)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(titleColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .typesettingLanguage(Locale.Language(identifier: "ja"))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if state.isRevealed, let detail {
                    Group {
                        if detailIsGlyph {
                            GlyphText(text: detail, size: 22, color: subtitleColor)
                        } else {
                            Text(detail)
                                .font(.system(size: 13, weight: .medium))
                                .typesettingLanguage(Locale.Language(identifier: "ja"))
                                .foregroundStyle(subtitleColor)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .frame(minHeight: height)
            .background(shape.fill(fill))
            .overlay(
                shape.strokeBorder(border, lineWidth: borderWidth)
            )
            .contentShape(shape)
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.97))
        .allowsHitTesting(!state.isRevealed)
        .opacity(state == .dimmed ? 0.6 : 1)
        .scaleEffect(state == .selected ? 1.02 : 1)
        .lessonShake(trigger: state == .wrong ? 1 : 0)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: state)
        .accessibilityAddTraits(state == .correct || state == .selected ? [.isButton, .isSelected] : .isButton)
    }

    private var fill: Color {
        switch state {
        case .idle, .selected, .dimmed: theme.bg._300
        case .correct: MojiTint.correct
        case .wrong: MojiTint.wrong
        }
    }

    private var border: Color {
        switch state {
        case .selected: theme.text.primary
        case .idle, .dimmed, .correct, .wrong: theme.border._200.opacity(theme.isDark ? 1 : 0.6)
        }
    }

    private var borderWidth: CGFloat {
        switch state {
        case .selected: 2
        case .idle, .dimmed: 1
        case .correct, .wrong: 0
        }
    }

    private var titleColor: Color {
        switch state {
        case .idle, .selected, .dimmed: theme.text.primary
        case .correct, .wrong: .white
        }
    }

    private var subtitleColor: Color {
        switch state {
        case .idle, .selected, .dimmed: theme.text.secondary
        case .correct, .wrong: Color.white.opacity(0.85)
        }
    }
}

extension MojiCharacter {
    var optionDetailLine: String {
        guard let meaning = shortMeaning else { return romaji }
        return "\(readingLine) · \(meaning)"
    }
}

struct LessonShakeModifier: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat.zero, trigger: trigger) { view, offset in
            view.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(CGFloat(8), duration: 0.06)
                LinearKeyframe(CGFloat(-8), duration: 0.08)
                LinearKeyframe(CGFloat(6), duration: 0.08)
                LinearKeyframe(CGFloat(-4), duration: 0.08)
                LinearKeyframe(CGFloat.zero, duration: 0.06)
            }
        }
    }
}

extension View {
    func lessonShake(trigger: Int) -> some View {
        modifier(LessonShakeModifier(trigger: trigger))
    }
}

struct LessonPromptTile: View {
    var glyph: String? = nil
    var title: String? = nil
    var subtitle: String? = nil
    var side: CGFloat = 170
    var showsSpeaker = false
    var action: (() -> Void)? = nil

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)
        let face = ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 6) {
                if let glyph {
                    GlyphText(
                        text: glyph,
                        size: glyph.count > 2 ? side * 0.3 : (glyph.count == 2 ? side * 0.36 : side * 0.5),
                        color: theme.text.primary
                    )
                }
                if let title {
                    Text(title)
                        .font(.system(size: glyph == nil ? side * 0.2 : side * 0.12, weight: .bold))
                        .foregroundStyle(theme.text.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.45)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: max(13, side * 0.085), weight: .semibold))
                        .typesettingLanguage(Locale.Language(identifier: "ja"))
                        .foregroundStyle(theme.text.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .padding(side * 0.1)
            .frame(width: side, height: side)

            if showsSpeaker {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.text.secondary)
                    .padding(14)
            }
        }
        .background(shape.fill(theme.bg._300))
        .overlay(shape.strokeBorder(theme.border._200.opacity(theme.isDark ? 1 : 0.6), lineWidth: 1))

        if let action {
            Button(action: action) {
                face.contentShape(shape)
            }
            .buttonStyle(PressableButtonStyle())
        } else {
            face
        }
    }
}
