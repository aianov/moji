import Foundation
import Testing
@testable import Moji

@Suite("Notes and folders")
struct MojiNoteRepositoryTests {
    private static let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func at(_ minutes: Double) -> Date {
        Self.start.addingTimeInterval(minutes * 60)
    }

    private func scratchDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("moji-notes-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeRepository(at directory: URL) -> MojiNoteRepository {
        makeRepository(store: MojiDiskStore(directory: directory))
    }

    private func makeRepository(store: MojiDiskStore) -> MojiNoteRepository {
        MojiNoteRepository(resources: MojiNoteResourceRepository(store: store))
    }

    private func writeLibrary(_ value: String, in directory: URL, version: Int = 1) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let envelope = #"{"savedAt":0,"value":"# + value + #","version":"# + String(version) + "}"
        try Data(envelope.utf8).write(to: directory.appendingPathComponent(MojiNoteResourceRepository.libraryKey.fileName))
    }

    @Test("A note is created, edited and deleted; a blank one is never kept")
    func notesLifecycle() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = makeRepository(at: directory)

        let empty = await repository.activate()
        #expect(empty.isLoaded)
        #expect(empty.notes.isEmpty)
        #expect(empty.folders.isEmpty)

        #expect(await repository.saveNote(id: "a", title: "  ", body: "\n \u{3000}\n", folderID: nil, now: at(0)) == nil)
        #expect(await repository.currentSnapshot().notes.isEmpty)

        let created = try #require(await repository.saveNote(id: "a", title: "Particles", body: "は marks the topic", folderID: nil, now: at(1)))
        #expect(created.createdAt == at(1))
        #expect(created.updatedAt == at(1))
        #expect(created.folderID == nil)
        #expect(!created.isPinned)

        let unchanged = try #require(await repository.saveNote(id: "a", title: "Particles", body: "は marks the topic", folderID: nil, now: at(5)))
        #expect(unchanged.updatedAt == at(1))

        let edited = try #require(await repository.saveNote(id: "a", title: "Particles", body: "は marks the topic\nが marks the subject", folderID: nil, now: at(6)))
        #expect(edited.createdAt == at(1))
        #expect(edited.updatedAt == at(6))
        #expect(await repository.currentSnapshot().note("a")?.body == "は marks the topic\nが marks the subject")

        #expect(await repository.discardIfEmpty(id: "a") == false)
        _ = await repository.saveNote(id: "a", title: "", body: "   ", folderID: nil, now: at(7))
        #expect(await repository.currentSnapshot().note("a") != nil)
        #expect(await repository.discardIfEmpty(id: "a"))
        #expect(await repository.currentSnapshot().notes.isEmpty)

        _ = await repository.saveNote(id: "b", title: "", body: "食べる to eat", folderID: nil, now: at(8))
        let removed = try #require(await repository.deleteNote(id: "b"))
        #expect(removed.body == "食べる to eat")
        #expect(await repository.deleteNote(id: "b") == nil)
        #expect(await repository.currentSnapshot().notes.isEmpty)

        #expect(await repository.restoreNote(removed))
        #expect(await repository.restoreNote(removed) == false)
        #expect(await repository.currentSnapshot().notes == [removed])
    }

    @Test("Folders are created, renamed and reordered; deleting one keeps its notes in All")
    func foldersLifecycle() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = makeRepository(at: directory)
        _ = await repository.activate()

        let grammar = try #require(await repository.createFolder(named: "  Grammar\n ", now: at(0)))
        #expect(grammar.name == "Grammar")
        #expect(await repository.createFolder(named: " \n ", now: at(0)) == nil)
        let long = try #require(await repository.createFolder(named: String(repeating: "語", count: 60), now: at(1)))
        #expect(long.name.count == MojiNoteText.folderNameLimit)
        let kanji = try #require(await repository.createFolder(named: "Kanji", now: at(2)))
        #expect(await repository.currentSnapshot().folders.map(\.id) == [grammar.id, long.id, kanji.id])

        await repository.renameFolder(long.id, to: "  Words  ")
        await repository.renameFolder(kanji.id, to: "   ")
        var snapshot = await repository.currentSnapshot()
        #expect(snapshot.folder(long.id)?.name == "Words")
        #expect(snapshot.folder(kanji.id)?.name == "Kanji")

        _ = await repository.saveNote(id: "n1", title: "は and が", body: "", folderID: grammar.id, now: at(3))
        _ = await repository.saveNote(id: "n2", title: "日 and 目", body: "", folderID: "missing", now: at(4))
        _ = await repository.saveNote(id: "n3", title: "Loose", body: "", folderID: nil, now: at(5))
        snapshot = await repository.currentSnapshot()
        #expect(snapshot.note("n1")?.folderID == grammar.id)
        #expect(snapshot.note("n2")?.folderID == nil)

        await repository.moveNote("n2", toFolder: kanji.id)
        await repository.moveNote("n3", toFolder: "missing")
        snapshot = await repository.currentSnapshot()
        #expect(snapshot.notes(in: kanji.id).map(\.id) == ["n2"])
        #expect(snapshot.note("n3")?.folderID == nil)
        #expect(snapshot.count(in: grammar.id) == 1)
        #expect(snapshot.count(in: nil) == 3)

        await repository.reorderFolders([kanji.id, "ghost", grammar.id])
        #expect(await repository.currentSnapshot().folders.map(\.id) == [kanji.id, grammar.id, long.id])

        await repository.deleteFolder(grammar.id)
        snapshot = await repository.currentSnapshot()
        #expect(snapshot.folders.map(\.id) == [kanji.id, long.id])
        #expect(snapshot.note("n1")?.folderID == nil)
        #expect(snapshot.notes(in: nil).count == 3)
        #expect(snapshot.notes(in: grammar.id).isEmpty)

        await repository.moveNote("n2", toFolder: nil)
        #expect(await repository.currentSnapshot().note("n2")?.folderID == nil)

        let deletedFolderNote = try #require(await repository.deleteNote(id: "n3"))
        await repository.moveNote("n1", toFolder: kanji.id)
        await repository.deleteFolder(kanji.id)
        var orphan = deletedFolderNote
        orphan.folderID = kanji.id
        #expect(await repository.restoreNote(orphan))
        #expect(await repository.currentSnapshot().note("n3")?.folderID == nil)
    }

    @Test("Pinned notes come first, then the most recently edited")
    func ordering() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = makeRepository(at: directory)
        _ = await repository.activate()

        _ = await repository.saveNote(id: "old", title: "Old", body: "", folderID: nil, now: at(0))
        _ = await repository.saveNote(id: "mid", title: "Mid", body: "", folderID: nil, now: at(1))
        _ = await repository.saveNote(id: "new", title: "New", body: "", folderID: nil, now: at(2))
        #expect(await repository.currentSnapshot().notes.map(\.id) == ["new", "mid", "old"])

        await repository.setPinned(true, noteID: "old")
        var snapshot = await repository.currentSnapshot()
        #expect(snapshot.notes.map(\.id) == ["old", "new", "mid"])
        #expect(snapshot.note("old")?.updatedAt == at(0))
        #expect(snapshot.note("old")?.isPinned == true)

        _ = await repository.saveNote(id: "mid", title: "Mid", body: "edited", folderID: nil, now: at(3))
        #expect(await repository.currentSnapshot().notes.map(\.id) == ["old", "mid", "new"])

        await repository.setPinned(true, noteID: "new")
        #expect(await repository.currentSnapshot().notes.map(\.id) == ["new", "old", "mid"])

        await repository.setPinned(false, noteID: "old")
        await repository.setPinned(false, noteID: "new")
        snapshot = await repository.currentSnapshot()
        #expect(snapshot.notes.map(\.id) == ["mid", "new", "old"])
        #expect(snapshot.notes.allSatisfy { !$0.isPinned })
    }

    @Test("Notes, folders, pins and order survive a restart")
    func persistence() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = makeRepository(at: directory)
        _ = await first.activate()
        let grammar = try #require(await first.createFolder(named: "Grammar", now: at(0)))
        let kanji = try #require(await first.createFolder(named: "漢字", now: at(1)))
        await first.reorderFolders([kanji.id, grammar.id])
        _ = await first.saveNote(id: "n1", title: "て-form", body: "食べる → 食べて\n飲む → 飲んで", folderID: grammar.id, now: at(2))
        _ = await first.saveNote(id: "n2", title: "", body: "Ещё одна запись", folderID: nil, now: at(3))
        await first.setPinned(true, noteID: "n1")
        let saved = await first.currentSnapshot()

        let second = makeRepository(at: directory)
        let restored = await second.activate()
        #expect(restored.folders == saved.folders)
        #expect(restored.notes == saved.notes)
        #expect(restored.notes.map(\.id) == ["n1", "n2"])
        #expect(restored.note("n1")?.folderID == grammar.id)
        #expect(restored.note("n1")?.isPinned == true)
        #expect(restored.note("n1")?.createdAt == at(2))
        #expect(restored.generation == 0)
    }

    @Test("reloadFromDisk picks up data written behind the repository and republishes it")
    func reloadFromDisk() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MojiDiskStore(directory: directory)
        let shown = MojiNoteSnapshotBox()
        let repository = makeRepository(store: store)
        await repository.setPublisher { snapshot in
            await shown.append(snapshot)
        }
        _ = await repository.activate()
        _ = await repository.saveNote(id: "mine", title: "Before the import", body: "", folderID: nil, now: at(0))

        let importer = makeRepository(store: store)
        _ = await importer.activate()
        let folder = try #require(await importer.createFolder(named: "Imported", now: at(1)))
        _ = await importer.saveNote(id: "theirs", title: "From the backup", body: "", folderID: folder.id, now: at(2))
        await importer.setPinned(true, noteID: "theirs")
        let imported = await importer.currentSnapshot()

        #expect(await repository.currentSnapshot().note("theirs") == nil)

        let reloaded = await repository.reloadFromDisk()
        #expect(reloaded.isLoaded)
        #expect(reloaded.generation == 1)
        #expect(reloaded.folders == imported.folders)
        #expect(reloaded.notes == imported.notes)
        #expect(await shown.last == reloaded)

        _ = await repository.saveNote(id: "after", title: "Written after the reload", body: "", folderID: folder.id, now: at(3))
        let afterRestart = await makeRepository(at: directory).activate()
        #expect(Set(afterRestart.notes.map(\.id)) == ["mine", "theirs", "after"])
        #expect(afterRestart.note("after")?.folderID == folder.id)

        await store.remove(MojiNoteResourceRepository.libraryKey)
        let cleared = await repository.reloadFromDisk()
        #expect(cleared.generation == 2)
        #expect(cleared.notes.isEmpty)
        #expect(cleared.folders.isEmpty)
        #expect(await shown.last == cleared)
    }

    @Test("A damaged file never crashes; only its broken parts are lost")
    func damagedFiles() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileName = MojiNoteResourceRepository.libraryKey.fileName

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json at all".utf8).write(to: directory.appendingPathComponent(fileName))
        let unreadable = await makeRepository(at: directory).activate()
        #expect(unreadable.isLoaded)
        #expect(unreadable.notes.isEmpty)
        let kept = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(kept.contains { $0.hasPrefix("notes.library.corrupt-") })

        try writeLibrary("[1,2,3]", in: directory)
        #expect(await makeRepository(at: directory).activate().notes.isEmpty)

        try writeLibrary(#"{"notes":"nope","folders":7}"#, in: directory)
        #expect(await makeRepository(at: directory).activate().notes.isEmpty)

        try writeLibrary(#"{"notes":[{"id":"n1","title":"Future","body":""}]}"#, in: directory, version: 9)
        #expect(await makeRepository(at: directory).activate().notes.isEmpty)

        try writeLibrary(
            #"""
            {"folders":[{"id":"f1","name":"Grammar","createdAt":10},{"id":"","name":"No id"},{"name":"Missing id"},
              {"id":"f2","name":"  "},42,{"id":"f1","name":"Duplicate"},{"id":"f3","name":"Words\nand more"}],
             "notes":[{"id":"n1","title":"Kept","body":"text","folderID":"f1","isPinned":true,"createdAt":100,"updatedAt":200},
              {"id":"n2","body":"Lost its folder","folderID":"f2"},
              {"id":"n3","title":"  ","body":"\n"},
              {"title":"No id"},
              "oops",
              {"id":"n4","title":5,"body":"A title of the wrong type","updatedAt":300,"isPinned":"yes"},
              {"id":"n1","title":"Older copy","body":"x","updatedAt":50},
              {"id":"n5","title":"Moved","body":"","folderID":"f3","createdAt":400}]}
            """#,
            in: directory
        )
        let repository = makeRepository(at: directory)
        let snapshot = await repository.activate()
        #expect(snapshot.folders.map(\.id) == ["f1", "f3"])
        #expect(snapshot.folder("f1")?.name == "Grammar")
        #expect(snapshot.folder("f3")?.name == "Words and more")
        #expect(snapshot.notes.map(\.id) == ["n1", "n5", "n4", "n2"])

        let first = try #require(snapshot.note("n1"))
        #expect(first.title == "Kept")
        #expect(first.isPinned)
        #expect(first.folderID == "f1")
        #expect(first.createdAt == Date(timeIntervalSince1970: 100))
        #expect(first.updatedAt == Date(timeIntervalSince1970: 200))

        #expect(snapshot.note("n2")?.folderID == nil)
        #expect(snapshot.note("n2")?.createdAt == Date(timeIntervalSince1970: 0))
        #expect(snapshot.note("n3") == nil)
        #expect(snapshot.note("n4")?.title == "")
        #expect(snapshot.note("n4")?.isPinned == false)
        #expect(snapshot.note("n4")?.createdAt == Date(timeIntervalSince1970: 300))
        #expect(snapshot.note("n5")?.updatedAt == Date(timeIntervalSince1970: 400))

        _ = await repository.saveNote(id: "n6", title: "Still writable", body: "", folderID: "f1", now: at(0))
        let reopened = await makeRepository(at: directory).activate()
        #expect(reopened.note("n6")?.folderID == "f1")
        #expect(reopened.notes.count == 5)
    }
}

private actor MojiNoteSnapshotBox {
    private(set) var values: [MojiNoteRepositorySnapshot] = []

    func append(_ snapshot: MojiNoteRepositorySnapshot) {
        values.append(snapshot)
    }

    var last: MojiNoteRepositorySnapshot? {
        values.last
    }
}
