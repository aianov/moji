import SwiftUI

struct ProfilePage: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: ProfileServicesStore { .shared }
    private var interactions: ProfileInteractionsStore { .shared }

    var body: some View {
        let isSettingsPresented = Binding(
            get: { service.isSettingsPresented },
            set: { if !$0 { interactions.closeSettings() } }
        )

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    StreakHeroCard()
                    ProfileStatsRow()
                    ContributionGraphCard()
                    ScriptProgressCard()
                    WordsProgressCard()

                    Text("Moji keeps everything on this iPhone.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.text.secondary.opacity(0.7))
                        .padding(.top, 6)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background {
                AppBackground()
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        interactions.openSettings()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(Text("Settings"))
                }
            }
        }
        .sheet(isPresented: isSettingsPresented) {
            ProfileSettingsSheet()
                .themedPresentation()
        }
    }
}

struct ProfileCardBackground: ViewModifier {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.radius._100 + 4, style: .continuous)

        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(theme.bg._300.opacity(theme.isDark ? 0.92 : 1)))
            .overlay(
                shape.strokeBorder(
                    theme.border._200.opacity(theme.isDark ? 0.9 : 0.45),
                    lineWidth: 1
                )
            )
    }
}

extension View {
    func profileCard() -> some View {
        modifier(ProfileCardBackground())
    }
}
