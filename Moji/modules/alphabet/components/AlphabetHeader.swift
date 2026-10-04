import SwiftUI

struct AlphabetHeader: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var practice: PracticeServicesStore { .shared }
    private var service: AlphabetServicesStore { .shared }
    private var interactions: AlphabetInteractionsStore { .shared }

    var body: some View {
        let activity = practice.activity

        HStack(alignment: .center, spacing: 10) {
            Text("Practice")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(theme.text.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            AlphabetMasteryMenu(page: service.activePage)

            StreakPill(
                streak: activity.currentStreak,
                isLit: activity.isTodayDone,
                action: { interactions.openProfile() }
            )
        }
        .frame(height: 44)
    }
}

struct AlphabetMasteryMenu: View {
    let page: MojiPage

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: AlphabetServicesStore { .shared }
    private var interactions: AlphabetInteractionsStore { .shared }

    var body: some View {
        Menu {
            Button {
                interactions.requestMarkKnown(page)
            } label: {
                Label("Mark all \(page.title) as known", systemImage: "checkmark.circle")
            }

            Menu {
                ForEach(service.sections(page)) { section in
                    Button(service.title(of: section)) {
                        interactions.requestMarkKnown(section)
                    }
                }
            } label: {
                Label("Mark a section as known", systemImage: "square.stack.3d.up")
            }

            Divider()

            Menu {
                Button(role: .destructive) {
                    interactions.requestReset(page)
                } label: {
                    Text("All of \(page.title)")
                }
                ForEach(service.sections(page)) { section in
                    Button(service.title(of: section), role: .destructive) {
                        interactions.requestReset(section)
                    }
                }
            } label: {
                Label("Reset mastery", systemImage: "arrow.counterclockwise")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.text.primary)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
                .liquidChromeCircle(interactive: true)
        }
        .accessibilityLabel(Text("Set mastery"))
    }
}

struct StreakPill: View {
    let streak: Int
    let isLit: Bool
    let action: () -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        LiquidGlassButton(
            shape: .capsule,
            size: 40,
            horizontalPadding: 14,
            accessibilityLabel: String(localized: "\(streak) day streak"),
            action: action
        ) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isLit ? AnyShapeStyle(MojiTint.flame) : AnyShapeStyle(theme.text.secondary.opacity(0.6)))
                    .symbolEffect(.bounce, value: isLit)
                Text("\(streak)")
                    .font(.system(size: 17, weight: .bold).monospacedDigit())
                    .foregroundStyle(isLit ? theme.text.primary : theme.text.secondary)
                    .contentTransition(.numericText(value: Double(streak)))
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: streak)
        }
    }
}
