import SwiftUI

struct NotesEmptyState: View {
    let kind: NotesEmptyKind

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: NotesInteractionsStore { .shared }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(theme.text.secondary.opacity(0.7))
                .padding(.bottom, 4)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.text.primary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(theme.text.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if kind != .noResults {
                LiquidGlassButton(
                    shape: .capsule,
                    size: 44,
                    horizontalPadding: 18,
                    action: { interactions.createNote() }
                ) {
                    Label("New note", systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.text.primary)
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var symbol: String {
        switch kind {
        case .noNotes: "note.text"
        case .emptyFolder: "folder"
        case .noResults: "magnifyingglass"
        }
    }

    private var title: String {
        switch kind {
        case .noNotes: String(localized: "No notes yet")
        case .emptyFolder: String(localized: "This folder is empty")
        case .noResults: String(localized: "No notes found")
        }
    }

    private var message: String {
        switch kind {
        case .noNotes: String(localized: "Write down grammar, new words or anything else. Tap + to start.")
        case .emptyFolder: String(localized: "New notes you start here go into this folder.")
        case .noResults: String(localized: "Search looks through the titles and text of all notes.")
        }
    }
}
