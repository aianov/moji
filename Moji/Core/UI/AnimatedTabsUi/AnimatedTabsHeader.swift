import SwiftUI

struct AnimatedTabsHeader<ID: Hashable>: View {
    let tabs: [TabHeaderConfig<ID>]
    let selection: ID
    let liveState: AnimatedTabsLiveState
    let onSelect: (ID) -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        GeometryReader { geometry in
            let innerWidth = geometry.size.width - AnimatedTabsMetrics.barInnerPadding * 2
            let tabWidth = tabs.isEmpty ? 0 : innerWidth / CGFloat(tabs.count)

            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    AnimatedTabsLabel(
                        text: tab.text,
                        isActive: tab.id == selection,
                        width: tabWidth,
                        theme: theme,
                        onTap: { onSelect(tab.id) }
                    )
                }
            }
            .background(alignment: .leading) {
                AnimatedTabsIndicator(
                    liveState: liveState,
                    tabCount: tabs.count,
                    tabWidth: tabWidth,
                    theme: theme
                )
            }
            .padding(.horizontal, AnimatedTabsMetrics.barInnerPadding)
            .frame(width: geometry.size.width, height: AnimatedTabsMetrics.barHeight)
        }
        .frame(height: AnimatedTabsMetrics.barHeight)
        .liquidChromeCapsule()
    }
}

private struct AnimatedTabsIndicator: View {
    let liveState: AnimatedTabsLiveState
    let tabCount: Int
    let tabWidth: CGFloat
    let theme: AppTheme

    var body: some View {
        let maxPosition = CGFloat(max(0, tabCount - 1))
        let position = min(maxPosition, max(0, liveState.position))
        let shape = RoundedRectangle(
            cornerRadius: AnimatedTabsMetrics.indicatorCornerRadius,
            style: .continuous
        )

        shape
            .fill(theme.isDark ? theme.bg._500.opacity(0.9) : Color.white.opacity(0.95))
            .overlay(
                shape.stroke(
                    theme.isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.06),
                    lineWidth: 0.5
                )
            )
            .shadow(color: .black.opacity(theme.isDark ? 0 : 0.08), radius: 6, y: 2)
            .frame(
                width: max(0, tabWidth),
                height: AnimatedTabsMetrics.barHeight - AnimatedTabsMetrics.barInnerPadding * 2
            )
            .offset(x: position * tabWidth)
    }
}

private struct AnimatedTabsLabel: View {
    let text: String
    let isActive: Bool
    let width: CGFloat
    let theme: AppTheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(.system(size: AnimatedTabsMetrics.tabFontSize, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? theme.text.primary : theme.text.secondary)
                .lineLimit(1)
                .frame(
                    width: max(0, width),
                    height: AnimatedTabsMetrics.barHeight - AnimatedTabsMetrics.barInnerPadding * 2
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : [.isButton])
    }
}
