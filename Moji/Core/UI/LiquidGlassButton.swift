import SwiftUI

enum LiquidGlassButtonShape {
    case circle
    case capsule
}

struct LiquidGlassButton<Label: View>: View {
    var shape: LiquidGlassButtonShape = .circle
    var size: CGFloat = 44
    var horizontalPadding: CGFloat = 16
    var tint: Color? = nil
    var disabled: Bool = false
    var accessibilityLabel: String? = nil
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            sizedLabel
        }
        .buttonStyle(.plain)
        .modifier(GlassShapeModifier(shape: shape, tint: tint))
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .modifier(OptionalAccessibilityLabel(text: accessibilityLabel))
    }

    @ViewBuilder
    private var sizedLabel: some View {
        switch shape {
        case .circle:
            label()
                .frame(width: size, height: size)
                .contentShape(Circle())
        case .capsule:
            label()
                .padding(.horizontal, horizontalPadding)
                .frame(minHeight: size)
                .contentShape(Capsule())
        }
    }
}

private struct GlassShapeModifier: ViewModifier {
    let shape: LiquidGlassButtonShape
    let tint: Color?

    func body(content: Content) -> some View {
        switch shape {
        case .circle:
            content.liquidChromeCircle(tint: tint, interactive: true)
        case .capsule:
            content.liquidChromeCapsule(tint: tint, interactive: true)
        }
    }
}

struct OptionalAccessibilityLabel: ViewModifier {
    let text: String?

    func body(content: Content) -> some View {
        if let text {
            content.accessibilityLabel(Text(text))
        } else {
            content
        }
    }
}

struct PressableButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(
                .spring(response: 0.28, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}
