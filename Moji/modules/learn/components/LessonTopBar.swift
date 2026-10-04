import SwiftUI

struct LessonTopBar: View {
    let progress: Double
    let onClose: () -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        HStack(spacing: 14) {
            LiquidGlassButton(
                shape: .circle,
                size: 44,
                accessibilityLabel: String(localized: "Close"),
                action: onClose
            ) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(theme.text.secondary)
            }

            ProgressBarUi(
                progress: progress,
                height: 10,
                track: theme.bg._500,
                fill: theme.text.primary
            )
        }
        .padding(.top, 6)
    }
}
