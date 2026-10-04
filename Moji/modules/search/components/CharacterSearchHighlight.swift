import SwiftUI

extension CharacterSearchMark {
    var isFound: Bool {
        self != .unmatched
    }

    var borderWidth: CGFloat {
        self == .current ? 2.5 : 1.5
    }

    func fill(_ theme: AppTheme) -> Color {
        switch self {
        case .unmatched: .clear
        case .match: MojiTint.highlight.opacity(theme.isDark ? 0.2 : 0.3)
        case .current: MojiTint.highlight.opacity(theme.isDark ? 0.32 : 0.48)
        }
    }

    func border(_ theme: AppTheme) -> Color {
        switch self {
        case .unmatched: .clear
        case .match: MojiTint.highlight.opacity(theme.isDark ? 0.75 : 0.9)
        case .current: MojiTint.highlight
        }
    }
}

extension View {
    func characterSearchMark(_ mark: CharacterSearchMark, cornerRadius: CGFloat) -> some View {
        modifier(CharacterSearchMarkModifier(mark: mark, cornerRadius: cornerRadius))
    }
}

private struct CharacterSearchMarkModifier: ViewModifier {
    let mark: CharacterSearchMark
    let cornerRadius: CGFloat

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background(shape.fill(mark.fill(theme)))
            .overlay {
                if mark.isFound {
                    shape
                        .strokeBorder(mark.border(theme), lineWidth: mark.borderWidth)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOut(duration: 0.2), value: mark)
    }
}
