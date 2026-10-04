import SwiftUI

@MainActor
@Observable
final class NotesInteractionsStore {
    static let shared = NotesInteractionsStore()

    static let undoDuration: Duration = .seconds(5)
    static let toastAnimation = Animation.snappy(duration: 0.3)

    var actions: NotesActionsStore { .shared }
    var service: NotesServicesStore { .shared }

    @ObservationIgnored var saveTask: Task<Void, Never>?
    @ObservationIgnored var saveChain: Task<Void, Never>?
    @ObservationIgnored var pendingSince: Date?
    @ObservationIgnored var countsTask: Task<Void, Never>?
    @ObservationIgnored private var undoTask: Task<Void, Never>?

    private init() {
        MojiEngineRuntime.shared.registerReload(
            "notes-editor",
            flush: { await NotesInteractionsStore.flushPendingEdits() },
            reload: {}
        )
    }

    static func flushPendingEdits() async {
        shared.flushEditor()
        await shared.saveChain?.value
    }

    func setQuery(_ query: String) {
        guard service.query != query else { return }
        service.query = query
    }

    func selectFolder(_ folderID: String?) {
        guard service.activeFolderID != folderID else { return }
        service.activeFolderID = folderID
        if let folderID {
            UserDefaults.standard.set(folderID, forKey: NotesServicesStore.activeFolderKey)
        } else {
            UserDefaults.standard.removeObject(forKey: NotesServicesStore.activeFolderKey)
        }
        MojiHaptics.selection()
    }

    func createNote() {
        MojiHaptics.selection()
        let id = UUID().uuidString
        service.query = ""
        service.editor = NotesEditorState(newNoteID: id, folderID: service.selectedFolderID)
        service.editorCounts = .zero
        service.path = [.note(id)]
    }

    func openNote(_ note: MojiNote) {
        service.editor = NotesEditorState(note: note)
        service.editorCounts = MojiNoteText.counts(note.body)
        service.path = [.note(note.id)]
    }

    func setPath(_ path: [NotesRoute]) {
        let removed = service.path.filter { !path.contains($0) }
        service.path = path
        for case .note(let noteID) in removed {
            closeEditor(noteID)
        }
    }

    func togglePin(_ note: MojiNote) {
        MojiHaptics.selection()
        Task {
            await actions.setPinnedAction(!note.isPinned, noteID: note.id)
        }
    }

    func requestMove(_ noteID: String) {
        MojiHaptics.selection()
        service.sheet = .move(noteID)
    }

    func move(noteID: String, to folderID: String?) {
        if var editor = service.editor, editor.noteID == noteID {
            editor.folderID = folderID
            service.editor = editor
        }
        service.sheet = nil
        MojiHaptics.success()
        Task {
            await actions.moveNoteAction(noteID, to: folderID)
        }
    }

    func delete(_ note: MojiNote) {
        MojiHaptics.impact()
        service.hiddenNoteIDs.insert(note.id)
        Task {
            let removed = await actions.deleteNoteAction(note.id)
            service.hiddenNoteIDs.remove(note.id)
            if let removed {
                showUndo(removed)
            }
        }
    }

    func showUndo(_ note: MojiNote) {
        let undo = NotesUndo(note: note, token: UUID())
        withAnimation(Self.toastAnimation) {
            service.undo = undo
        }
        undoTask?.cancel()
        undoTask = Task {
            try? await Task.sleep(for: Self.undoDuration)
            guard !Task.isCancelled, service.undo?.token == undo.token else { return }
            withAnimation(Self.toastAnimation) {
                service.undo = nil
            }
        }
    }

    func undoDelete() {
        guard let undo = service.undo else { return }
        undoTask?.cancel()
        withAnimation(Self.toastAnimation) {
            service.undo = nil
        }
        MojiHaptics.success()
        Task {
            await actions.restoreNoteAction(undo.note)
        }
    }

    func openFolderEditor() {
        MojiHaptics.selection()
        service.sheet = .folders
    }

    func closeSheet() {
        service.sheet = nil
    }

    func requestNewFolder(selectsFolder: Bool, movingNote noteID: String? = nil) {
        MojiHaptics.selection()
        service.folderNameDraft = ""
        service.folderPrompt = .create(selectsFolder: selectsFolder, noteID: noteID)
    }

    func requestRename(_ folder: MojiNoteFolder) {
        MojiHaptics.selection()
        service.folderNameDraft = folder.name
        service.folderPrompt = .rename(folder.id)
    }

    func setFolderNameDraft(_ name: String) {
        service.folderNameDraft = name
    }

    func commitFolderPrompt() {
        guard let prompt = service.folderPrompt else { return }
        let name = service.folderNameDraft
        service.folderPrompt = nil
        switch prompt {
        case .create(let selectsFolder, let noteID):
            Task {
                guard let folder = await actions.createFolderAction(name) else { return }
                if let noteID {
                    move(noteID: noteID, to: folder.id)
                } else if selectsFolder {
                    selectFolder(folder.id)
                } else {
                    MojiHaptics.success()
                }
            }
        case .rename(let folderID):
            Task {
                await actions.renameFolderAction(folderID, name: name)
            }
        }
    }

    func cancelFolderPrompt() {
        service.folderPrompt = nil
    }

    func requestDeleteFolder(_ folder: MojiNoteFolder) {
        MojiHaptics.selection()
        service.pendingFolderDeletion = folder
    }

    func requestDeleteFolder(at offsets: IndexSet) {
        let folders = service.folders
        guard let index = offsets.first, folders.indices.contains(index) else { return }
        requestDeleteFolder(folders[index])
    }

    func confirmDeleteFolder() {
        guard let folder = service.pendingFolderDeletion else { return }
        service.pendingFolderDeletion = nil
        if service.activeFolderID == folder.id {
            service.activeFolderID = nil
            UserDefaults.standard.removeObject(forKey: NotesServicesStore.activeFolderKey)
        }
        MojiHaptics.impact()
        Task {
            await actions.deleteFolderAction(folder.id)
        }
    }

    func cancelDeleteFolder() {
        service.pendingFolderDeletion = nil
    }

    func moveFolders(from source: IndexSet, to destination: Int) {
        reorderFolders(MojiNoteOrder.moved(service.folders.map(\.id), from: source, to: destination))
    }

    func shiftFolder(_ folder: MojiNoteFolder, by offset: Int) {
        MojiHaptics.selection()
        reorderFolders(MojiNoteOrder.shifted(service.folders.map(\.id), moving: folder.id, by: offset))
    }

    func syncAfterReload() {
        service.reloadFromDefaults()
        service.hiddenNoteIDs = []
        service.folderOrderOverride = nil
        undoTask?.cancel()
        service.undo = nil
        reseedEditorAfterReload()
    }

    private func reorderFolders(_ ids: [String]) {
        guard ids != service.folders.map(\.id) else { return }
        service.folderOrderOverride = ids
        Task {
            await actions.reorderFoldersAction(ids)
            if service.folderOrderOverride == ids {
                service.folderOrderOverride = nil
            }
        }
    }
}
