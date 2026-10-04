import SwiftUI

struct NotesHeader: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: NotesServicesStore { .shared }
    private var interactions: NotesInteractionsStore { .shared }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Notes")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(theme.text.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            NotesMenu()

            LiquidGlassButton(
                shape: .circle,
                size: 40,
                disabled: !service.isLoaded,
                accessibilityLabel: String(localized: "New note"),
                action: { interactions.createNote() }
            ) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.text.primary)
            }
        }
        .frame(height: 44)
    }
}

struct NotesMenu: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: NotesInteractionsStore { .shared }

    var body: some View {
        Menu {
            Button {
                interactions.requestNewFolder(selectsFolder: true)
            } label: {
                Label("New folder", systemImage: "folder.badge.plus")
            }
            Button {
                interactions.openFolderEditor()
            } label: {
                Label("Edit folders", systemImage: "list.bullet")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.text.primary)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
                .liquidChromeCircle(interactive: true)
        }
        .accessibilityLabel(Text("Notes menu"))
    }
}
