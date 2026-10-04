import SwiftUI

struct AppBackground: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        theme.bg._100
            .ignoresSafeArea()
    }
}
