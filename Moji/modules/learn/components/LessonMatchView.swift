import SwiftUI

struct LessonMatchView: View {
    let left: [MojiCharacter]
    let right: [MojiCharacter]

    private var service: LearnServicesStore { .shared }
    private var interactions: LearnInteractionsStore { .shared }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 10) {
                ForEach(left) { character in
                    LessonMatchTile(
                        text: character.glyph,
                        isGlyph: true,
                        isSelected: service.matchSelectedLeft == character.id,
                        isMatched: service.matchedIDs.contains(character.id),
                        wasMissed: service.matchMissedIDs.contains(character.id),
                        shakeToken: shakeToken(for: character.id),
                        action: { interactions.tapMatchLeft(character.id) }
                    )
                }
            }
            VStack(spacing: 10) {
                ForEach(right) { character in
                    LessonMatchTile(
                        text: LessonBuilder.matchLabel(character),
                        isGlyph: false,
                        isSelected: service.matchSelectedRight == character.id,
                        isMatched: service.matchedIDs.contains(character.id),
                        wasMissed: service.matchMissedIDs.contains(character.id),
                        shakeToken: shakeToken(for: character.id),
                        action: { interactions.tapMatchRight(character.id) }
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity)
    }

    private func shakeToken(for id: String) -> Int {
        guard let shake = service.matchShake, shake.ids.contains(id) else { return 0 }
        return shake.token
    }
}

private struct LessonMatchTile: View {
    let text: String
    let isGlyph: Bool
    let isSelected: Bool
    let isMatched: Bool
    let wasMissed: Bool
    let shakeToken: Int
    let action: () -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        Button(action: action) {
            Group {
                if isGlyph {
                    GlyphText(
                        text: text,
                        size: text.count > 2 ? 22 : 28,
                        color: isMatched ? theme.text.secondary : theme.text.primary
                    )
                } else {
                    Text(text)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isMatched ? theme.text.secondary : theme.text.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                }
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(shape.fill(isSelected ? theme.bg._500 : theme.bg._300))
            .overlay(shape.strokeBorder(borderColor, lineWidth: isSelected || isMatched ? 1.5 : 1))
            .contentShape(shape)
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.96))
        .allowsHitTesting(!isMatched)
        .opacity(isMatched ? 0.45 : 1)
        .lessonShake(trigger: shakeToken)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isMatched)
    }

    private var borderColor: Color {
        if isMatched { return MojiTint.correct }
        if isSelected { return theme.text.primary }
        if wasMissed { return MojiTint.wrong.opacity(0.7) }
        return theme.border._200.opacity(theme.isDark ? 1 : 0.6)
    }
}
