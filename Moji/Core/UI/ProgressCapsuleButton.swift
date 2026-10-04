import SwiftUI

enum ProgressCapsuleRole {
    case primary
    case success
    case error
    case secondary
}

struct ProgressCapsuleButton: View {
    let title: String
    var detail: String? = nil
    var systemImage: String? = nil
    var progress: Double? = nil
    var role: ProgressCapsuleRole = .primary
    var height: CGFloat = 56
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    private var fill: Color {
        switch role {
        case .primary: theme.text.primary
        case .success: MojiTint.correct
        case .error: MojiTint.wrong
        case .secondary: theme.bg._400
        }
    }

    private var label: Color {
        switch role {
        case .primary: theme.bg._100
        case .success, .error: .white
        case .secondary: theme.text.primary
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                if let detail {
                    Text(detail)
                        .font(.system(size: 15, weight: .medium).monospacedDigit())
                        .opacity(0.6)
                        .contentTransition(.numericText())
                }
            }
            .foregroundStyle(label)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(fill)
            .overlay(alignment: .leading) {
                if let progress, progress > 0 {
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(label.opacity(0.12))
                            .frame(width: max(height / 2, geometry.size.width * min(1, progress)))
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipShape(Capsule(style: .continuous))
            .contentShape(Capsule(style: .continuous))
            .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.97))
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: progress)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}
