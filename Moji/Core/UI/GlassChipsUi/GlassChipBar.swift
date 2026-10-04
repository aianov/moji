import SwiftUI

struct GlassChip<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    var symbol: String? = nil
}

extension GlassChip: Sendable where ID: Sendable {}

enum GlassChipMetrics {
    static let height: CGFloat = 36
    static let spacing: CGFloat = 8
    static let selectAnimation = Animation.smooth(duration: 0.35)
}

struct GlassChipBar<ID: Hashable>: View {
    let chips: [GlassChip<ID>]
    let selection: ID
    var accessibilityLabel: String? = nil
    let onSelect: (ID) -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                GlassEffectContainer(spacing: GlassChipMetrics.spacing) {
                    HStack(spacing: GlassChipMetrics.spacing) {
                        ForEach(chips) { chip in
                            GlassChipButton(
                                chip: chip,
                                isSelected: chip.id == selection,
                                theme: theme,
                                action: { onSelect(chip.id) }
                            )
                            .id(chip.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .onAppear {
                proxy.scrollTo(selection, anchor: .center)
            }
            .onChange(of: selection) { _, newValue in
                withAnimation(GlassChipMetrics.selectAnimation) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .frame(height: GlassChipMetrics.height + 4)
        .accessibilityElement(children: .contain)
        .modifier(OptionalAccessibilityLabel(text: accessibilityLabel))
    }
}

private struct GlassChipButton<ID: Hashable>: View {
    let chip: GlassChip<ID>
    let isSelected: Bool
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol = chip.symbol {
                    Text(verbatim: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .typesettingLanguage(Locale.Language(identifier: "ja"))
                        .opacity(isSelected ? 1 : 0.75)
                }
                Text(chip.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(isSelected ? theme.bg._100 : theme.text.primary)
            .padding(.horizontal, 14)
            .frame(height: GlassChipMetrics.height)
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .liquidChromeCapsule(tint: isSelected ? theme.text.primary : nil, interactive: true)
        .animation(GlassChipMetrics.selectAnimation, value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}
