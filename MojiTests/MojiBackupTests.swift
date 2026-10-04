import Foundation
import Testing
@testable import Moji

@Suite("Backup: export and import")
struct MojiBackupTests {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    static let exportedAt = Date(timeIntervalSince1970: 1_791_115_200)
    static let importedAt = Date(timeIntervalSince1970: 1_791_201_600)
    static let laterImportAt = Date(timeIntervalSince1970: 1_791_288_000)
    static let seenAt = Date(timeIntervalSince1970: 1_790_000_000)
    static let progressKey = MojiDiskKey(namespace: "practice", name: "progress")

    private struct Sandbox {
        let root: URL
        let suite: String

        init() {
            root = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("moji-backup-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            #if os(macOS)
            suite = root.appendingPathComponent("defaults", isDirectory: false).path
            #else
            suite = "moji-backup-tests-\(UUID().uuidString)"
            #endif
        }

        var storeDirectory: URL {
            root.appendingPathComponent("Moji", isDirectory: true)
        }

        var safetyDirectory: URL {
            root.appendingPathComponent("MojiSafetyCopy", isDirectory: true)
        }

        func defaults() throws -> UserDefaults {
            try #require(UserDefaults(suiteName: suite))
        }

        func repository(_ store: MojiDiskStore) throws -> MojiBackupRepository {
            MojiBackupRepository(
                store: store,
                defaults: try defaults(),
                safetyDirectory: safetyDirectory,
                appVersion: "test",
                calendar: MojiBackupTests.calendar
            )
        }

        func write(_ text: String, to name: String) throws {
            let url = storeDirectory.appendingPathComponent(name, isDirectory: false)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(text.utf8).write(to: url)
        }

        func storedFiles() throws -> [String: Data] {
            let manager = FileManager.default
            guard manager.fileExists(atPath: storeDirectory.path) else { return [:] }
            var files: [String: Data] = [:]
            for path in try manager.subpathsOfDirectory(atPath: storeDirectory.path) {
                let url = storeDirectory.appendingPathComponent(path, isDirectory: false)
                var isFolder: ObjCBool = false
                guard manager.fileExists(atPath: url.path, isDirectory: &isFolder), !isFolder.boolValue else {
                    continue
                }
                files[path] = try Data(contentsOf: url)
            }
            return files
        }

        func settings() throws -> NSDictionary {
            NSDictionary(dictionary: try defaults().dictionaryRepresentation().filter { $0.key.hasPrefix("moji.") })
        }

        func safetyFiles() -> [String] {
            ((try? FileManager.default.contentsOfDirectory(atPath: safetyDirectory.path)) ?? []).sorted()
        }

        func clean() {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
    }

    private func fillOldPhone(_ sandbox: Sandbox, store: MojiDiskStore) async throws {
        await store.write(
            [
                "h-a": MojiCharacterProgress(strength: 5, seen: 6, correct: 6, lastSeenAt: Self.seenAt),
                "j-日": MojiCharacterProgress(strength: 0, seen: 0, correct: 0, lastSeenAt: nil, writtenAt: Self.seenAt),
                "k-a": MojiCharacterProgress.fresh
            ],
            key: Self.progressKey,
            version: 1
        )

        var reviewed = MojiWordCard()
        reviewed.phase = .review
        reviewed.interval = 4
        reviewed.dueDay = 20_000
        reviewed.easeFactor = 2_500
        reviewed.reps = 3
        await store.write(
            MojiWordLossyMap(["t1": reviewed, "t2": MojiWordCard()]),
            key: MojiDiskKey(namespace: "words", name: "cards"),
            version: 1
        )

        await store.write(
            MojiLearnState(pages: [
                "hiragana": MojiLearnPageState(
                    introducedIDs: ["h-a", "h-i"],
                    freshIDs: ["h-i"],
                    lessonsCompleted: 2,
                    lastLessonAt: Self.seenAt
                )
            ]),
            key: MojiDiskKey(namespace: "learn", name: "state"),
            version: 1
        )

        try sandbox.write(#"{"savedAt":0,"value":[{"id":"my-1"},{"id":"my-2"}],"version":1}"#, to: "words.mine.json")
        try sandbox.write(
            #"{"savedAt":0,"value":{"folders":[],"notes":["#
                + #"{"id":"n1","body":"日本","updatedAt":10},"#
                + #"{"id":"n1","body":"日本語","updatedAt":20},"#
                + #"{"id":"n2","title":"","body":"   "}"#
                + #"]},"version":1}"#,
            to: MojiNoteResourceRepository.libraryKey.fileName
        )
        try sandbox.write("a module the backup has never heard of", to: "future.module.json")
        try sandbox.write("sketch bytes", to: "attachments/sketch.bin")
        try sandbox.write("Finder junk", to: ".DS_Store")

        let defaults = try sandbox.defaults()
        defaults.set("dark", forKey: "moji.theme.appearance.v1")
        defaults.set(false, forKey: "moji.preferences.speaks_characters.v1")
        defaults.set("katakana", forKey: "moji.learn.active_script.v1")
        defaults.set(7, forKey: "moji.future.count")
        defaults.set(Self.seenAt, forKey: "moji.future.date")
        defaults.set(["a", "b"], forKey: "moji.future.list")
        defaults.set("old iPhone", forKey: "elsewhere.key")
    }

    private func fillNewPhone(_ sandbox: Sandbox, store: MojiDiskStore) async throws {
        await store.write(
            ["h-ka": MojiCharacterProgress(strength: 2, seen: 3, correct: 2, lastSeenAt: Self.seenAt)],
            key: Self.progressKey,
            version: 1
        )
        try sandbox.write("only on the new iPhone", to: "old.only.json")

        let defaults = try sandbox.defaults()
        defaults.set("light", forKey: "moji.theme.appearance.v1")
        defaults.set(3, forKey: "moji.only.here")
        defaults.set("new iPhone", forKey: "elsewhere.key")
    }

    private static func rewritten(_ data: Data, _ change: (inout [String: Any]) throws -> Void) throws -> Data {
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        try change(&object)
        return try JSONSerialization.data(withJSONObject: object)
    }

    private static func rewrittenFirstFile(_ data: Data, _ change: @escaping (inout [String: Any]) -> Void) throws -> Data {
        try rewritten(data) { object in
            var store = try #require(object["store"] as? [[String: Any]])
            change(&store[0])
            object["store"] = store
        }
    }

    @Test("Export then import gives the new iPhone the same files and moji settings")
    func roundTrip() async throws {
        let old = Sandbox()
        let new = Sandbox()
        defer {
            old.clean()
            new.clean()
        }
        let oldStore = MojiDiskStore(directory: old.storeDirectory)
        let newStore = MojiDiskStore(directory: new.storeDirectory)
        try await fillOldPhone(old, store: oldStore)
        try await fillNewPhone(new, store: newStore)

        let export = try await old.repository(oldStore).export(now: Self.exportedAt)
        #expect(export.filename == "Moji backup 2026-10-04.json")
        #expect(export.manifest.appVersion == "test")
        #expect(export.manifest.exportedAt == Self.exportedAt)
        #expect(export.manifest.counts == MojiBackupCounts(characters: 2, wordCards: 1, ownCards: 2, notes: 1))
        #expect(export.manifest.fileCount == 7)
        #expect(export.manifest.settingCount == 6)

        let repository = try new.repository(newStore)
        #expect(try await repository.inspect(export.data) == export.manifest)
        _ = try await repository.restore(export.data, now: Self.importedAt)

        var expected = try old.storedFiles()
        expected[".DS_Store"] = nil
        #expect(try new.storedFiles() == expected)
        #expect(try new.settings() == old.settings())

        let defaults = try new.defaults()
        #expect(defaults.string(forKey: "elsewhere.key") == "new iPhone")
        #expect(defaults.object(forKey: "moji.only.here") == nil)
        #expect(defaults.string(forKey: "moji.theme.appearance.v1") == "dark")
        #expect(defaults.integer(forKey: "moji.future.count") == 7)
        #expect(defaults.object(forKey: "moji.future.date") as? Date == Self.seenAt)
        #expect(defaults.stringArray(forKey: "moji.future.list") == ["a", "b"])
        let speaks = try #require(defaults.object(forKey: "moji.preferences.speaks_characters.v1") as? NSNumber)
        #expect(CFGetTypeID(speaks as CFTypeRef) == CFBooleanGetTypeID())
        #expect(speaks.boolValue == false)
    }

    @Test("The file is one readable JSON with the format and manifest on top")
    func fileFormat() async throws {
        let old = Sandbox()
        defer { old.clean() }
        let oldStore = MojiDiskStore(directory: old.storeDirectory)
        try await fillOldPhone(old, store: oldStore)

        let export = try await old.repository(oldStore).export(now: Self.exportedAt)
        let text = String(decoding: export.data, as: UTF8.self)
        #expect(text.hasPrefix("{\n  \"format\" : \"moji.backup\",\n  \"formatVersion\" : 1,"))

        let object = try #require(JSONSerialization.jsonObject(with: export.data) as? [String: Any])
        #expect(Set(object.keys) == ["format", "formatVersion", "manifest", "settings", "store"])
        let manifest = try #require(object["manifest"] as? [String: Any])
        #expect(manifest["exportedAt"] as? String == "2026-10-04T12:00:00Z")
        #expect(manifest["appVersion"] as? String == "test")

        let store = try #require(object["store"] as? [[String: Any]])
        let progress = try #require(store.first { $0["name"] as? String == "practice.progress.json" })
        let payload = try #require((progress["payload"] as? String).flatMap { Data(base64Encoded: $0) })
        #expect(payload == (try old.storedFiles())["practice.progress.json"])
        #expect(progress["sha256"] as? String == MojiBackupFile.digest(of: payload))
        #expect(progress["size"] as? Int == payload.count)
    }

    @Test("Files from namespaces the backup has never heard of travel too")
    func unknownNamespaces() async throws {
        let old = Sandbox()
        let new = Sandbox()
        defer {
            old.clean()
            new.clean()
        }
        let oldStore = MojiDiskStore(directory: old.storeDirectory)
        try old.write(#"{"savedAt":0,"value":{"anything":true},"version":3}"#, to: "kanjiquest.progress.json")
        try old.write("raw bytes, not json", to: "zz.cache.dat")
        try old.write("nested", to: "deep/nested/file.json")
        let futureKey = MojiDiskKey(namespace: "tomorrow", name: "feature")
        await oldStore.write(["x": 1], key: futureKey, version: 2)

        let export = try await old.repository(oldStore).export(now: Self.exportedAt)
        #expect(export.manifest.fileCount == 4)
        #expect(export.manifest.counts == MojiBackupCounts(characters: 0, wordCards: 0, ownCards: nil, notes: nil))

        let object = try #require(JSONSerialization.jsonObject(with: export.data) as? [String: Any])
        let names = try #require(object["store"] as? [[String: Any]]).compactMap { $0["name"] as? String }
        #expect(names == ["deep/nested/file.json", "kanjiquest.progress.json", "tomorrow.feature.json", "zz.cache.dat"])

        let newStore = MojiDiskStore(directory: new.storeDirectory)
        _ = try await new.repository(newStore).restore(export.data, now: Self.importedAt)
        #expect(try new.storedFiles() == old.storedFiles())
        #expect(await newStore.read([String: Int].self, key: futureKey, version: 2) == ["x": 1])
    }

    @Test("A broken file, a newer format and foreign files are refused and change nothing")
    func rejectedFilesChangeNothing() async throws {
        let old = Sandbox()
        let new = Sandbox()
        defer {
            old.clean()
            new.clean()
        }
        let oldStore = MojiDiskStore(directory: old.storeDirectory)
        let newStore = MojiDiskStore(directory: new.storeDirectory)
        try await fillOldPhone(old, store: oldStore)
        try await fillNewPhone(new, store: newStore)

        let export = try await old.repository(oldStore).export(now: Self.exportedAt)
        let text = String(decoding: export.data, as: UTF8.self)
        let repository = try new.repository(newStore)
        let filesBefore = try new.storedFiles()
        let settingsBefore = try new.settings()

        let cases: [(label: String, data: Data, error: MojiBackupError)] = [
            ("cut in half", export.data.prefix(export.data.count / 2), .damaged),
            ("empty file", Data(), .notBackup),
            (
                "newer format",
                Data(text.replacingOccurrences(of: "\"formatVersion\" : 1,", with: "\"formatVersion\" : 2,").utf8),
                .newerVersion
            ),
            ("no format version", Data(text.replacingOccurrences(of: "\"formatVersion\" : 1,", with: "").utf8), .damaged),
            ("foreign JSON", Data(#"{"name":"Anki deck","cards":[]}"#.utf8), .notBackup),
            ("JSON list", Data("[1, 2, 3]".utf8), .notBackup),
            ("not JSON", Data("PK zip bytes".utf8), .notBackup),
            (
                "file changed inside",
                try Self.rewrittenFirstFile(export.data) { $0["payload"] = Data("evil".utf8).base64EncodedString() },
                .damaged
            ),
            ("name leaving the folder", try Self.rewrittenFirstFile(export.data) { $0["name"] = "../escape.json" }, .damaged),
            (
                "file count off",
                try Self.rewritten(export.data) { object in
                    var manifest = try #require(object["manifest"] as? [String: Any])
                    manifest["fileCount"] = 99
                    object["manifest"] = manifest
                },
                .damaged
            ),
            (
                "setting outside moji",
                try Self.rewritten(export.data) { object in
                    let plist = try PropertyListSerialization.data(
                        fromPropertyList: ["AppleLanguages": ["ru"]],
                        format: .binary,
                        options: 0
                    )
                    object["settings"] = plist.base64EncodedString()
                    var manifest = try #require(object["manifest"] as? [String: Any])
                    manifest["settingCount"] = 1
                    object["manifest"] = manifest
                },
                .damaged
            )
        ]

        for entry in cases {
            await #expect(throws: entry.error, "\(entry.label)") {
                try await repository.inspect(entry.data)
            }
            await #expect(throws: entry.error, "\(entry.label)") {
                try await repository.restore(entry.data, now: Self.importedAt)
            }
        }

        #expect(try new.storedFiles() == filesBefore)
        #expect(try new.settings() == settingsBefore)
        #expect(new.safetyFiles().isEmpty)
        #expect(await repository.safetyCopy() == nil)
    }

    @Test("Import keeps a safety copy of this iPhone's data and undo brings it back")
    func safetyCopyAndUndo() async throws {
        let old = Sandbox()
        let new = Sandbox()
        defer {
            old.clean()
            new.clean()
        }
        let oldStore = MojiDiskStore(directory: old.storeDirectory)
        let newStore = MojiDiskStore(directory: new.storeDirectory)
        try await fillOldPhone(old, store: oldStore)
        try await fillNewPhone(new, store: newStore)

        let repository = try new.repository(newStore)
        let filesBefore = try new.storedFiles()
        let settingsBefore = try new.settings()
        #expect(await repository.safetyCopy() == nil)

        let export = try await old.repository(oldStore).export(now: Self.exportedAt)
        let copy = try #require(try await repository.restore(export.data, now: Self.importedAt))
        #expect(copy.exportedAt == Self.importedAt)
        #expect(copy.counts.characters == 1)
        #expect(copy.fileCount == 2)
        #expect(copy.settingCount == 2)
        #expect(await repository.safetyCopy() == copy)
        #expect(new.safetyFiles() == ["before-import.json"])
        #expect(try new.storedFiles() != filesBefore)

        try await repository.undo()
        #expect(try new.storedFiles() == filesBefore)
        #expect(try new.settings() == settingsBefore)
        #expect(await repository.safetyCopy() == nil)
        #expect(new.safetyFiles().isEmpty)
        await #expect(throws: MojiBackupError.noSafetyCopy) {
            try await repository.undo()
        }
    }

    @Test("The next import replaces the safety copy, so undo goes back one import")
    func nextImportReplacesSafetyCopy() async throws {
        let old = Sandbox()
        let new = Sandbox()
        let other = Sandbox()
        defer {
            old.clean()
            new.clean()
            other.clean()
        }
        let oldStore = MojiDiskStore(directory: old.storeDirectory)
        let newStore = MojiDiskStore(directory: new.storeDirectory)
        let otherStore = MojiDiskStore(directory: other.storeDirectory)
        try await fillOldPhone(old, store: oldStore)
        try await fillNewPhone(new, store: newStore)
        try other.write("from a third iPhone", to: "other.only.json")
        try other.defaults().set("system", forKey: "moji.theme.appearance.v1")

        let repository = try new.repository(newStore)
        let first = try await old.repository(oldStore).export(now: Self.exportedAt)
        let second = try await other.repository(otherStore).export(now: Self.exportedAt)

        _ = try await repository.restore(first.data, now: Self.importedAt)
        let filesAfterFirst = try new.storedFiles()
        let settingsAfterFirst = try new.settings()

        let copy = try await repository.restore(second.data, now: Self.laterImportAt)
        #expect(copy?.exportedAt == Self.laterImportAt)
        #expect(copy?.counts.characters == 2)
        #expect(try new.storedFiles() == other.storedFiles())
        #expect(new.safetyFiles() == ["before-import.json"])

        try await repository.undo()
        #expect(try new.storedFiles() == filesAfterFirst)
        #expect(try new.settings() == settingsAfterFirst)
    }

    @Test("An empty backup empties the other iPhone, and undo still brings its data back")
    func emptyBackup() async throws {
        let empty = Sandbox()
        let new = Sandbox()
        defer {
            empty.clean()
            new.clean()
        }
        let emptyStore = MojiDiskStore(directory: empty.storeDirectory)
        let newStore = MojiDiskStore(directory: new.storeDirectory)
        try await fillNewPhone(new, store: newStore)
        let filesBefore = try new.storedFiles()

        let export = try await empty.repository(emptyStore).export(now: Self.exportedAt)
        #expect(export.manifest.fileCount == 0)
        #expect(export.manifest.counts == MojiBackupCounts(characters: 0, wordCards: 0, ownCards: nil, notes: nil))

        let repository = try new.repository(newStore)
        _ = try await repository.restore(export.data, now: Self.importedAt)
        #expect(try new.storedFiles().isEmpty)
        #expect(try new.settings().count == 0)
        #expect(try new.defaults().string(forKey: "elsewhere.key") == "new iPhone")

        try await repository.undo()
        #expect(try new.storedFiles() == filesBefore)
    }

    @Test("The disk store forgets cached files when the data is replaced")
    func diskCacheIsCleared() async throws {
        let old = Sandbox()
        let new = Sandbox()
        defer {
            old.clean()
            new.clean()
        }
        let oldStore = MojiDiskStore(directory: old.storeDirectory)
        let newStore = MojiDiskStore(directory: new.storeDirectory)
        try await fillOldPhone(old, store: oldStore)
        try await fillNewPhone(new, store: newStore)

        let cached = await newStore.read([String: MojiCharacterProgress].self, key: Self.progressKey, version: 1)
        #expect(cached?["h-ka"]?.strength == 2)

        let export = try await old.repository(oldStore).export(now: Self.exportedAt)
        _ = try await new.repository(newStore).restore(export.data, now: Self.importedAt)

        let fresh = await newStore.read([String: MojiCharacterProgress].self, key: Self.progressKey, version: 1)
        #expect(fresh?["h-ka"] == nil)
        #expect(fresh?["h-a"]?.strength == 5)

        let key = MojiDiskKey(namespace: "test", name: "value")
        await newStore.write("cached", key: key, version: 1)
        try new.write(#"{"savedAt":0,"value":"on disk","version":1}"#, to: key.fileName)
        #expect(await newStore.read(String.self, key: key, version: 1) == "cached")
        await newStore.clearMemory()
        #expect(await newStore.read(String.self, key: key, version: 1) == "on disk")
    }

    @Test("Practice, learn and words publish the imported data after a reload in place")
    func domainsReloadInPlace() async throws {
        let old = Sandbox()
        let new = Sandbox()
        defer {
            old.clean()
            new.clean()
        }
        let oldStore = MojiDiskStore(directory: old.storeDirectory)
        let newStore = MojiDiskStore(directory: new.storeDirectory)
        try await fillOldPhone(old, store: oldStore)
        try await fillNewPhone(new, store: newStore)

        let practice = MojiPracticeRepository(
            resources: MojiPracticeResourceRepository(store: newStore),
            catalog: .shared
        )
        let learn = MojiLearnRepository(
            resources: MojiLearnResourceRepository(store: newStore),
            planner: .shared
        )
        let catalog = MojiWordTestSupport.catalog(count: 3)
        let words = MojiWordRepository(
            resources: MojiWordResourceRepository(store: newStore),
            catalogLoader: { catalog },
            calendar: MojiWordTestSupport.calendar,
            learningFuzz: { 0 }
        )
        #expect(await practice.activate().progress["h-ka"]?.strength == 2)
        #expect(await learn.activate().state.pages.isEmpty)
        #expect(await words.activate().cards.isEmpty)

        let published = MojiBackupPublishedSnapshots()
        await practice.setPublisher { await published.record(practice: $0) }
        await learn.setPublisher { await published.record(learn: $0) }
        await words.setPublisher { await published.record(words: $0) }

        let export = try await old.repository(oldStore).export(now: Self.exportedAt)
        _ = try await new.repository(newStore).restore(export.data, now: Self.importedAt)

        await practice.reloadFromDisk()
        await learn.reloadFromDisk()
        await words.reloadFromDisk()

        let shownPractice = try #require(await published.practice)
        #expect(shownPractice.progress["h-ka"] == nil)
        #expect(shownPractice.progress["h-a"]?.strength == 5)
        #expect(shownPractice.progress["j-日"]?.isWritten == true)
        #expect(shownPractice.pageStats[.hiragana]?.practiced == 1)

        let shownLearn = try #require(await published.learn)
        #expect(shownLearn.state.state(for: .hiragana).introducedIDs == ["h-a", "h-i"])

        let shownWords = try #require(await published.words)
        #expect(shownWords.cards["t1"]?.phase == .review)
    }

    @MainActor
    @Test("The runtime reloads every registered domain once and flushes before replacing data")
    func runtimeReloads() async throws {
        let log = MojiBackupEventLog()
        let runtime = MojiEngineRuntime.shared
        runtime.registerReload("backup-tests") { await log.add("stale") }
        runtime.registerReload("backup-tests", flush: { await log.add("flush") }) { await log.add("reload") }

        await runtime.reloadAll()
        #expect(await log.events == ["reload"])

        let value = try await runtime.replaceData {
            await log.add("replace")
            return 42
        }
        #expect(value == 42)
        #expect(await log.events == ["reload", "flush", "replace", "reload"])

        await #expect(throws: MojiBackupError.writeFailed) {
            try await runtime.replaceData { () async throws -> Int in
                throw MojiBackupError.writeFailed
            }
        }
        #expect(await log.events == ["reload", "flush", "replace", "reload", "flush"])
    }
}

private actor MojiBackupPublishedSnapshots {
    var practice: MojiPracticeRepositorySnapshot?
    var learn: MojiLearnRepositorySnapshot?
    var words: MojiWordRepositorySnapshot?

    func record(practice snapshot: MojiPracticeRepositorySnapshot) {
        practice = snapshot
    }

    func record(learn snapshot: MojiLearnRepositorySnapshot) {
        learn = snapshot
    }

    func record(words snapshot: MojiWordRepositorySnapshot) {
        words = snapshot
    }
}

private actor MojiBackupEventLog {
    var events: [String] = []

    func add(_ event: String) {
        events.append(event)
    }
}
