import Foundation
import Observation

@MainActor
@Observable
final class NotesServicesStore {
    static let shared = NotesServicesStore()

    static let activeFolderKey = "moji.notes.active_folder.v1"

    var activeFolderID: String?
    var query = ""
    var path: [NotesRoute] = []
    var editor: NotesEditorState?
    var editorCounts = MojiNoteCounts.zero
    var sheet: NotesSheet?
    var folderPrompt: NotesFolderPrompt?
    var folderNameDraft = ""
    var pendingFolderDeletion: MojiNoteFolder?
    var undo: NotesUndo?
    var hiddenNoteIDs: Set<String> = []
    var folderOrderOverride: [String]?

    @ObservationIgnored private var searchCache: NotesSearchCache?

    private init() {
        activeFolderID = UserDefaults.standard.string(forKey: Self.activeFolderKey)
    }

    func reloadFromDefaults() {
        let stored = UserDefaults.standard.string(forKey: Self.activeFolderKey)
        guard stored != activeFolderID else { return }
        activeFolderID = stored
    }

    var snapshot: MojiNoteRepositorySnapshot {
        MojiNotePresentation.shared.snapshot
    }

    var isLoaded: Bool {
        snapshot.isLoaded
    }

    var folders: [MojiNoteFolder] {
        guard let folderOrderOverride else { return snapshot.folders }
        return MojiNoteOrder.reordered(snapshot.folders, by: folderOrderOverride)
    }

    var selectedFolder: MojiNoteFolder? {
        snapshot.folder(activeFolderID)
    }

    var selectedFolderID: String? {
        selectedFolder?.id
    }

    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var searchTerms: [String] {
        MojiNoteSearch.terms(query)
    }

    var allNotes: [MojiNote] {
        guard !hiddenNoteIDs.isEmpty else { return snapshot.notes }
        return snapshot.notes.filter { !hiddenNoteIDs.contains($0.id) }
    }

    var visibleNotes: [MojiNote] {
        guard let folderID = selectedFolderID else { return allNotes }
        return allNotes.filter { $0.folderID == folderID }
    }

    func searchResults() -> [MojiNoteSearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let notes = allNotes
        if let searchCache, searchCache.query == trimmed, searchCache.notes == notes {
            return searchCache.hits
        }
        let hits = MojiNoteSearch.results(in: notes, query: trimmed)
        searchCache = NotesSearchCache(query: trimmed, notes: notes, hits: hits)
        return hits
    }

    func folderName(of note: MojiNote) -> String? {
        snapshot.folder(note.folderID)?.name
    }

    func noteCount(in folder: MojiNoteFolder) -> Int {
        snapshot.count(in: folder.id)
    }

    func folderID(ofNote noteID: String) -> String? {
        if let editor, editor.noteID == noteID {
            return editor.folderID
        }
        return snapshot.note(noteID)?.folderID
    }

    func editor(for noteID: String) -> NotesEditorState? {
        guard let editor, editor.noteID == noteID else { return nil }
        return editor
    }

    var editedNote: MojiNote? {
        editor.flatMap { snapshot.note($0.noteID) }
    }
}

private struct NotesSearchCache {
    let query: String
    let notes: [MojiNote]
    let hits: [MojiNoteSearchHit]
}
