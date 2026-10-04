import Foundation
import Observation

@MainActor
@Observable
final class NotesActionsStore {
    static let shared = NotesActionsStore()

    private init() {}

    private func repository() async -> MojiNoteRepository {
        await MojiNoteDomainRegistry.shared.requireDomain().repository
    }

    func saveNoteAction(_ editor: NotesEditorState) async -> MojiNote? {
        await repository().saveNote(
            id: editor.noteID,
            title: editor.title,
            body: editor.body,
            folderID: editor.folderID,
            now: Date()
        )
    }

    func discardIfEmptyAction(_ noteID: String) async {
        await repository().discardIfEmpty(id: noteID)
    }

    func deleteNoteAction(_ noteID: String) async -> MojiNote? {
        await repository().deleteNote(id: noteID)
    }

    func restoreNoteAction(_ note: MojiNote) async {
        await repository().restoreNote(note)
    }

    func setPinnedAction(_ pinned: Bool, noteID: String) async {
        await repository().setPinned(pinned, noteID: noteID)
    }

    func moveNoteAction(_ noteID: String, to folderID: String?) async {
        await repository().moveNote(noteID, toFolder: folderID)
    }

    func createFolderAction(_ name: String) async -> MojiNoteFolder? {
        await repository().createFolder(named: name, now: Date())
    }

    func renameFolderAction(_ folderID: String, name: String) async {
        await repository().renameFolder(folderID, to: name)
    }

    func deleteFolderAction(_ folderID: String) async {
        await repository().deleteFolder(folderID)
    }

    func reorderFoldersAction(_ ids: [String]) async {
        await repository().reorderFolders(ids)
    }
}
