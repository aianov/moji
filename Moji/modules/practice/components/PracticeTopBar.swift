import SwiftUI

struct PracticeTopBar: View {
    let answered: Int
    let total: Int
    let combo: Int
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
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.text.secondary)
            }

            ProgressBarUi(
                progress: total > 0 ? Double(answered) / Double(total) : 0,
                height: 10,
                track: theme.bg._400,
                fill: theme.text.primary
            )
            .overlay(alignment: .top) {
                Text("COMBO ×\(combo)")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(MojiTint.gold)
                    .contentTransition(.numericText(value: Double(combo)))
                    .opacity(combo >= 2 ? 1 : 0)
                    .offset(y: -20)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: combo)
                    .accessibilityHidden(combo < 2)
            }

            Text("\(answered)/\(total)")
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(theme.text.secondary)
                .contentTransition(.numericText(value: Double(answered)))
                .frame(minWidth: 56, alignment: .trailing)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: answered)
        }
        .padding(.top, 14)
    }
}
