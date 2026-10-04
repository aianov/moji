import SwiftUI

struct ThemeRootBoundary<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    private let content: Content

    private var themeStore: ThemeStore { .shared }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .preferredColorScheme(themeStore.preferredColorScheme)
            .tint(themeStore.currentTheme.text.primary)
            .onAppear {
                themeStore.systemColorSchemeDidChange(colorScheme)
            }
            .onChange(of: colorScheme) { _, newValue in
                themeStore.systemColorSchemeDidChange(newValue)
            }
    }
}

struct ThemedPresentation: ViewModifier {
    private var themeStore: ThemeStore { .shared }

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(themeStore.preferredColorScheme)
            .tint(themeStore.currentTheme.text.primary)
    }
}

extension View {
    func themedPresentation() -> some View {
        modifier(ThemedPresentation())
    }
}
