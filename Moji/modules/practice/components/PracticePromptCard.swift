import SwiftUI

struct PracticePromptCard: View {
    let model: PracticeQuestionModel
    let onSpeak: () -> Void

    private static let cornerRadius: CGFloat = 28

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)

        Group {
            if model.prompt.isGlyph {
                Button(action: onSpeak) {
                    face
                        .contentShape(shape)
                }
                .buttonStyle(PressableButtonStyle(pressedScale: 0.98))
                .accessibilityLabel(Text("Character \(model.prompt.title). Double tap to hear it."))
            } else {
                face
                    .accessibilityElement(children: .combine)
            }
        }
        .background(shape.fill(theme.bg._300))
        .overlay(
            shape
                .strokeBorder(theme.border._200.opacity(theme.isDark ? 1 : 0.55), lineWidth: 1)
                .allowsHitTesting(false)
        )
    }

    private var face: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)

            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: side * 0.04) {
                    if model.prompt.isGlyph {
                        GlyphText(
                            text: model.prompt.title,
                            size: glyphSize(side: side),
                            color: theme.text.primary
                        )
                        if let subtitle = model.prompt.subtitle {
                            Text(subtitle)
                                .font(.system(size: max(13, side * 0.09), weight: .medium))
                                .foregroundStyle(theme.text.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                        }
                    } else {
                        Text(model.prompt.title)
                            .font(
                                .system(
                                    size: side * (model.prompt.isMeaning ? 0.15 : 0.3),
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(theme.text.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(model.prompt.isMeaning ? 3 : 1)
                            .minimumScaleFactor(0.5)
                        if let subtitle = model.prompt.subtitle {
                            Text(subtitle)
                                .font(.system(size: max(12, side * 0.085), weight: .medium))
                                .typesettingLanguage(Locale.Language(identifier: "ja"))
                                .foregroundStyle(theme.text.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                }
                .padding(side * 0.1)
                .frame(width: geometry.size.width, height: geometry.size.height)

                if model.prompt.isGlyph {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: max(14, side * 0.08), weight: .semibold))
                        .foregroundStyle(theme.text.secondary)
                        .padding(max(12, side * 0.07))
                }
            }
        }
    }

    private func glyphSize(side: CGFloat) -> CGFloat {
        let scale: CGFloat = model.prompt.subtitle == nil ? 1 : 0.8
        switch model.prompt.title.count {
        case 1: return side * 0.5 * scale
        case 2: return side * 0.36 * scale
        default: return side * 0.26 * scale
        }
    }
}
