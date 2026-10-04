import SwiftUI

struct NotesFoldersSheet: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: NotesServicesStore { .shared }
    private var interactions: NotesInteractionsStore { .shared }

    var body: some View {
        let folders = service.folders

        NavigationStack {
            List {
                if folders.isEmpty {
                    Section {
                        Text("No folders yet")
                            .foregroundStyle(theme.text.secondary)
                    } footer: {
                        Text("Folders sort notes like chat folders in Telegram. All always shows every note.")
                    }
                } else {
                    Section {
                        ForEach(folders) { folder in
                            Button {
                                interactions.requestRename(folder)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder")
                                        .foregroundStyle(theme.text.secondary)
                                    Text(verbatim: folder.name)
                                        .typesettingLanguage(Locale.Language(identifier: "ja"))
                                        .foregroundStyle(theme.text.primary)
                                        .lineLimit(1)
                                    Spacer(minLength: 8)
                                    Text(service.noteCount(in: folder), format: .number)
                                        .monospacedDigit()
                                        .foregroundStyle(theme.text.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityHint(Text("Rename folder"))
                        }
                        .onMove { source, destination in
                            interactions.moveFolders(from: source, to: destination)
                        }
                        .onDelete { offsets in
                            interactions.requestDeleteFolder(at: offsets)
                        }
                    } footer: {
                        Text("Drag to change the order, tap a folder to rename it. Notes from a deleted folder stay in All.")
                    }
                }

                Section {
                    Button {
                        interactions.requestNewFolder(selectsFolder: false)
                    } label: {
                        Label("New folder", systemImage: "folder.badge.plus")
                            .foregroundStyle(theme.text.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Folders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        interactions.closeSheet()
                    }
                }
            }
        }
        .tint(theme.text.primary)
    }
}
