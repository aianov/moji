import SwiftUI

struct KanjiThemeBar: View {
    let selection: MojiKanjiTheme
    let onSelect: (MojiKanjiTheme) -> Void

    var body: some View {
        GlassChipBar(
            chips: MojiKanjiTheme.allCases.map { GlassChip(id: $0, title: $0.title, symbol: $0.symbol) },
            selection: selection,
            accessibilityLabel: String(localized: "Kanji themes"),
            onSelect: onSelect
        )
    }
}

struct KanjiThemeIntro: View {
    let theme: MojiKanjiTheme
    let count: Int

    private var appTheme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(theme.subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(appTheme.text.secondary)
            Text("\(count) kanji, the most common first")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(appTheme.text.secondary.opacity(0.75))
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
