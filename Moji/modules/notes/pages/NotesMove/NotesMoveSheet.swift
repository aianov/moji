import SwiftUI

struct NotesMoveSheet: View {
    let noteID: String

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: NotesServicesStore { .shared }
    private var interactions: NotesInteractionsStore { .shared }

    var body: some View {
        let current = service.folderID(ofNote: noteID)

        NavigationStack {
            List {
                Section {
                    NotesMoveRow(
                        title: String(localized: "No folder"),
                        systemImage: "tray",
                        isSelected: current == nil,
                        action: { interactions.move(noteID: noteID, to: nil) }
                    )
                    ForEach(service.folders) { folder in
                        NotesMoveRow(
                            title: folder.name,
                            systemImage: "folder",
                            isSelected: current == folder.id,
                            action: { interactions.move(noteID: noteID, to: folder.id) }
                        )
                    }
                } footer: {
                    Text("A note lives in one folder at most. All shows every note.")
                }

                Section {
                    Button {
                        interactions.requestNewFolder(selectsFolder: false, movingNote: noteID)
                    } label: {
                        Label("New folder", systemImage: "folder.badge.plus")
                            .foregroundStyle(theme.text.primary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Move to folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        interactions.closeSheet()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .tint(theme.text.primary)
    }
}

private struct NotesMoveRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(theme.text.secondary)
                Text(verbatim: title)
                    .typesettingLanguage(Locale.Language(identifier: "ja"))
                    .foregroundStyle(theme.text.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.text.primary)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}
