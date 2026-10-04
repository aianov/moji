import SwiftUI

struct NotesFolderAlerts: ViewModifier {
    let isActive: Bool

    private var service: NotesServicesStore { .shared }
    private var interactions: NotesInteractionsStore { .shared }

    func body(content: Content) -> some View {
        let isPromptPresented = Binding(
            get: { isActive && service.folderPrompt != nil },
            set: { if !$0 { interactions.cancelFolderPrompt() } }
        )
        let isDeletionPresented = Binding(
            get: { isActive && service.pendingFolderDeletion != nil },
            set: { if !$0 { interactions.cancelDeleteFolder() } }
        )
        let name = Binding(
            get: { service.folderNameDraft },
            set: { interactions.setFolderNameDraft($0) }
        )

        content
            .alert(
                promptTitle,
                isPresented: isPromptPresented,
                presenting: service.folderPrompt
            ) { prompt in
                TextField(String(localized: "Folder name"), text: name)
                Button(prompt.isCreate ? String(localized: "Create") : String(localized: "Save")) {
                    interactions.commitFolderPrompt()
                }
                .disabled(MojiNoteText.folderName(service.folderNameDraft) == nil)
                Button("Cancel", role: .cancel) {
                    interactions.cancelFolderPrompt()
                }
            }
            .alert(
                deletionTitle,
                isPresented: isDeletionPresented,
                presenting: service.pendingFolderDeletion
            ) { _ in
                Button("Delete", role: .destructive) {
                    interactions.confirmDeleteFolder()
                }
                Button("Cancel", role: .cancel) {
                    interactions.cancelDeleteFolder()
                }
            } message: { folder in
                let count = service.noteCount(in: folder)
                if count == 0 {
                    Text("This folder has no notes.")
                } else {
                    Text("\(count) notes from this folder stay in All.")
                }
            }
    }

    private var promptTitle: Text {
        switch service.folderPrompt {
        case .rename: Text("Rename folder")
        case .create, nil: Text("New folder")
        }
    }

    private var deletionTitle: Text {
        guard let folder = service.pendingFolderDeletion else { return Text(verbatim: "") }
        return Text("Delete the folder “\(folder.name)”?")
    }
}

extension View {
    func notesFolderAlerts(isActive: Bool) -> some View {
        modifier(NotesFolderAlerts(isActive: isActive))
    }
}
