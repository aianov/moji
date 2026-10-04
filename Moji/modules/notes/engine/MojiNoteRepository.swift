import Foundation

struct MojiNoteRepositorySnapshot: Equatable, Sendable {
    let isLoaded: Bool
    let generation: Int
    let folders: [MojiNoteFolder]
    let notes: [MojiNote]

    static let empty = MojiNoteRepositorySnapshot(
        isLoaded: false,
        generation: 0,
        folders: [],
        notes: []
    )

    func note(_ id: String) -> MojiNote? {
        notes.first { $0.id == id }
    }

    func folder(_ id: String?) -> MojiNoteFolder? {
        guard let id else { return nil }
        return folders.first { $0.id == id }
    }

    func notes(in folderID: String?) -> [MojiNote] {
        guard let folderID else { return notes }
        return notes.filter { $0.folderID == folderID }
    }

    func count(in folderID: String?) -> Int {
        guard let folderID else { return notes.count }
        return notes.reduce(0) { $1.folderID == folderID ? $0 + 1 : $0 }
    }
}

actor MojiNoteRepository {
    private let resources: MojiNoteResourceRepository

    private var folders: [MojiNoteFolder] = []
    private var notes: [String: MojiNote] = [:]
    private var generation = 0
    private var isLoaded = false
    private var loadTask: Task<Void, Never>?
    private var publish: (@Sendable (MojiNoteRepositorySnapshot) async -> Void)?

    init(resources: MojiNoteResourceRepository) {
        self.resources = resources
    }

    func setPublisher(_ publish: @escaping @Sendable (MojiNoteRepositorySnapshot) async -> Void) {
        self.publish = publish
    }

    func activate() async -> MojiNoteRepositorySnapshot {
        await ensureLoaded()
        return snapshot()
    }

    func currentSnapshot() async -> MojiNoteRepositorySnapshot {
        await ensureLoaded()
        return snapshot()
    }

    @discardableResult
    func saveNote(
        id: String,
        title: String,
        body: String,
        folderID: String?,
        now: Date
    ) async -> MojiNote? {
        await ensureLoaded()
        if var note = notes[id] {
            guard note.title != title || note.body != body else { return note }
            note.title = title
            note.body = body
            note.updatedAt = now
            notes[id] = note
            await commit()
            return note
        }
        guard !id.isEmpty, !MojiNoteText.isBlank(title: title, body: body) else { return nil }
        let note = MojiNote(
            id: id,
            title: title,
            body: body,
            folderID: existingFolder(folderID),
            isPinned: false,
            createdAt: now,
            updatedAt: now
        )
        notes[id] = note
        await commit()
        return note
    }

    @discardableResult
    func discardIfEmpty(id: String) async -> Bool {
        await ensureLoaded()
        guard let note = notes[id], note.isBlank else { return false }
        notes[id] = nil
        await commit()
        return true
    }

    @discardableResult
    func deleteNote(id: String) async -> MojiNote? {
        await ensureLoaded()
        guard let note = notes.removeValue(forKey: id) else { return nil }
        await commit()
        return note
    }

    @discardableResult
    func restoreNote(_ note: MojiNote) async -> Bool {
        await ensureLoaded()
        guard notes[note.id] == nil, !note.isBlank else { return false }
        var restored = note
        restored.folderID = existingFolder(note.folderID)
        notes[note.id] = restored
        await commit()
        return true
    }

    func setPinned(_ pinned: Bool, noteID: String) async {
        await ensureLoaded()
        guard var note = notes[noteID], note.isPinned != pinned else { return }
        note.isPinned = pinned
        notes[noteID] = note
        await commit()
    }

    func moveNote(_ noteID: String, toFolder folderID: String?) async {
        await ensureLoaded()
        guard var note = notes[noteID] else { return }
        let target = existingFolder(folderID)
        guard target == folderID, note.folderID != target else { return }
        note.folderID = target
        notes[noteID] = note
        await commit()
    }

    @discardableResult
    func createFolder(named name: String, now: Date) async -> MojiNoteFolder? {
        await ensureLoaded()
        guard let clean = MojiNoteText.folderName(name) else { return nil }
        let folder = MojiNoteFolder(id: UUID().uuidString, name: clean, createdAt: now)
        folders.append(folder)
        await commit()
        return folder
    }

    func renameFolder(_ id: String, to name: String) async {
        await ensureLoaded()
        guard let clean = MojiNoteText.folderName(name),
              let index = folders.firstIndex(where: { $0.id == id }),
              folders[index].name != clean else { return }
        folders[index].name = clean
        await commit()
    }

    func deleteFolder(_ id: String) async {
        await ensureLoaded()
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders.remove(at: index)
        for (key, note) in notes where note.folderID == id {
            notes[key]?.folderID = nil
        }
        await commit()
    }

    func reorderFolders(_ ids: [String]) async {
        await ensureLoaded()
        let order = MojiNoteOrder.reordered(folders, by: ids)
        guard order != folders else { return }
        folders = order
        await commit()
    }

    @discardableResult
    func reloadFromDisk() async -> MojiNoteRepositorySnapshot {
        if let loadTask {
            await loadTask.value
        }
        isLoaded = false
        let task = Task {
            await self.load(isReload: true)
        }
        loadTask = task
        await task.value
        let current = snapshot()
        await publish?(current)
        return current
    }

    private func existingFolder(_ id: String?) -> String? {
        guard let id, folders.contains(where: { $0.id == id }) else { return nil }
        return id
    }

    private func commit() async {
        let current = snapshot()
        await resources.save(MojiNoteLibrary(folders: current.folders, notes: current.notes))
        await publish?(current)
    }

    private func ensureLoaded() async {
        if isLoaded { return }
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task {
            await self.load(isReload: false)
        }
        loadTask = task
        await task.value
    }

    private func load(isReload: Bool) async {
        let library = await resources.load().sanitized()
        folders = library.folders
        notes = Dictionary(library.notes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if isReload {
            generation += 1
        }
        isLoaded = true
    }

    private func snapshot() -> MojiNoteRepositorySnapshot {
        MojiNoteRepositorySnapshot(
            isLoaded: isLoaded,
            generation: generation,
            folders: folders,
            notes: MojiNoteOrder.sorted(notes.values)
        )
    }
}
