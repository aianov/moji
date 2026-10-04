import Foundation

enum NotesRoute: Hashable {
    case note(String)
}

enum NotesSheet: Identifiable, Equatable {
    case folders
    case move(String)

    var id: String {
        switch self {
        case .folders: "folders"
        case .move(let noteID): "move#\(noteID)"
        }
    }
}

enum NotesFolderPrompt: Identifiable, Equatable {
    case create(selectsFolder: Bool, noteID: String?)
    case rename(String)

    var id: String {
        switch self {
        case .create(let selectsFolder, let noteID): "create#\(selectsFolder)#\(noteID ?? "")"
        case .rename(let folderID): "rename#\(folderID)"
        }
    }

    var isCreate: Bool {
        if case .create = self {
            return true
        }
        return false
    }
}

struct NotesUndo: Identifiable, Equatable {
    let note: MojiNote
    let token: UUID

    var id: UUID { token }
}

enum NotesEmptyKind: Equatable {
    case noNotes
    case emptyFolder
    case noResults
}

enum NotesFolderChipID: Hashable {
    case all
    case folder(String)
    case add
}

struct NotesEditorState: Equatable {
    let noteID: String
    var title: String
    var body: String
    var folderID: String?
    var savedTitle: String
    var savedBody: String
    var isPersisted: Bool

    init(newNoteID: String, folderID: String?) {
        noteID = newNoteID
        title = ""
        body = ""
        self.folderID = folderID
        savedTitle = ""
        savedBody = ""
        isPersisted = false
    }

    init(note: MojiNote) {
        noteID = note.id
        title = note.title
        body = note.body
        folderID = note.folderID
        savedTitle = note.title
        savedBody = note.body
        isPersisted = true
    }

    var isDirty: Bool {
        title != savedTitle || body != savedBody
    }

    var isFresh: Bool {
        !isPersisted && MojiNoteText.isBlank(title: title, body: body)
    }
}
