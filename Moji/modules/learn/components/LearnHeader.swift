import SwiftUI

struct LearnHeader: View {
    let page: MojiPage

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: LearnServicesStore { .shared }
    private var interactions: LearnInteractionsStore { .shared }

    var body: some View {
        let activity = service.activity

        HStack(alignment: .center, spacing: 10) {
            Text("Learn")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(theme.text.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            LearnKnownMenu(page: page)

            StreakPill(
                streak: activity.currentStreak,
                isLit: activity.isTodayDone,
                action: { interactions.openProfile() }
            )
        }
        .frame(height: 44)
    }
}

struct LearnKnownMenu: View {
    let page: MojiPage

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: LearnServicesStore { .shared }
    private var interactions: LearnInteractionsStore { .shared }

    var body: some View {
        Menu {
            Button {
                interactions.requestMarkPageKnown(page)
            } label: {
                Label("Mark all \(page.title) as known", systemImage: "checkmark.circle")
            }

            Menu {
                ForEach(service.sections(page)) { section in
                    Button(LearnInteractionsStore.title(of: section)) {
                        interactions.requestMarkSectionKnown(section)
                    }
                }
            } label: {
                Label("Mark a section as known", systemImage: "square.stack.3d.up")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.text.primary)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
                .liquidChromeCircle(interactive: true)
        }
        .accessibilityLabel(Text("Mark as known"))
    }
}
