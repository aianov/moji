import Foundation

actor MojiBackupRepository {
    static let shared = MojiBackupRepository(store: .shared)

    static let maximumFileSize = 256 * 1024 * 1024

    private static let safetyName = "before-import.json"
    private static let pendingName = "before-import.pending.json"

    private let store: MojiDiskStore
    private let defaults: UserDefaults
    private let safetyDirectory: URL
    private let appVersion: String
    private let calendar: Calendar

    init(
        store: MojiDiskStore,
        defaults: UserDefaults = .standard,
        safetyDirectory: URL? = nil,
        appVersion: String? = nil,
        calendar: Calendar = .current
    ) {
        self.store = store
        self.defaults = defaults
        self.safetyDirectory = safetyDirectory ?? Self.defaultSafetyDirectory()
        self.appVersion = appVersion ?? Self.bundleVersion()
        self.calendar = calendar
    }

    func export(now: Date) async throws -> MojiBackupExport {
        let archive = try await snapshot(now: now)
        return MojiBackupExport(
            data: try MojiBackupCodec.encode(archive),
            filename: Self.filename(for: now, calendar: calendar),
            manifest: archive.manifest
        )
    }

    func inspect(_ data: Data) throws -> MojiBackupManifest {
        try MojiBackupCodec.decode(data).manifest
    }

    func inspect(fileAt url: URL) throws -> MojiBackupPreview {
        let data = try Self.read(url)
        return MojiBackupPreview(data: data, manifest: try inspect(data))
    }

    func restore(_ data: Data, now: Date) async throws -> MojiBackupManifest? {
        let incoming = try MojiBackupCodec.decode(data)
        let current: MojiBackupArchive
        do {
            current = try await snapshot(now: now)
        } catch {
            throw MojiBackupError.writeFailed
        }
        let pending = try writePending(current)
        do {
            try await replaceFiles(with: incoming.files)
        } catch {
            try? FileManager.default.removeItem(at: pending)
            throw error
        }
        try? MojiBackupSettings.restore(incoming.settings, into: defaults)
        return promote(pending) ? current.manifest : nil
    }

    func undo() async throws {
        guard let data = try? Data(contentsOf: safetyURL) else {
            throw MojiBackupError.noSafetyCopy
        }
        let previous = try MojiBackupCodec.decode(data)
        try await replaceFiles(with: previous.files)
        try? MojiBackupSettings.restore(previous.settings, into: defaults)
        try? FileManager.default.removeItem(at: safetyURL)
    }

    func safetyCopy() -> MojiBackupManifest? {
        guard let data = try? Data(contentsOf: safetyURL) else { return nil }
        return try? MojiBackupCodec.decode(data).manifest
    }

    static func filename(for date: Date, calendar: Calendar) -> String {
        "Moji backup \(MojiDayKey.make(date, calendar: calendar)).json"
    }

    private var safetyURL: URL {
        safetyDirectory.appendingPathComponent(Self.safetyName, isDirectory: false)
    }

    private func snapshot(now: Date) async throws -> MojiBackupArchive {
        let files = try await store.withExclusiveAccess { directory in
            try MojiBackupDirectory.collect(directory)
        }
        let settings = try MojiBackupSettings.capture(from: defaults)
        return MojiBackupArchive(
            format: MojiBackupCodec.format,
            formatVersion: MojiBackupCodec.version,
            manifest: MojiBackupManifest(
                appVersion: appVersion,
                exportedAt: now,
                counts: MojiBackupCounter.counts(of: files),
                fileCount: files.count,
                settingCount: settings.count
            ),
            files: files,
            settings: settings.data
        )
    }

    private func replaceFiles(with files: [MojiBackupFile]) async throws {
        do {
            try await store.withExclusiveAccess { directory in
                try MojiBackupDirectory.replace(directory, with: files)
            }
        } catch {
            throw MojiBackupError.writeFailed
        }
    }

    private func writePending(_ archive: MojiBackupArchive) throws -> URL {
        let url = safetyDirectory.appendingPathComponent(Self.pendingName, isDirectory: false)
        do {
            try FileManager.default.createDirectory(at: safetyDirectory, withIntermediateDirectories: true)
            try MojiBackupCodec.encode(archive).write(
                to: url,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
        } catch {
            throw MojiBackupError.writeFailed
        }
        return url
    }

    private func promote(_ pending: URL) -> Bool {
        let manager = FileManager.default
        try? manager.removeItem(at: safetyURL)
        do {
            try manager.moveItem(at: pending, to: safetyURL)
            return true
        } catch {
            try? manager.removeItem(at: pending)
            return false
        }
    }

    private static func read(_ url: URL) throws -> Data {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        var coordinationError: NSError?
        var contents: Data?
        var isTooLarge = false
        NSFileCoordinator().coordinate(readingItemAt: url, options: [.withoutChanges], error: &coordinationError) { readable in
            let size = (try? readable.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            guard size <= maximumFileSize else {
                isTooLarge = true
                return
            }
            contents = try? Data(contentsOf: readable)
        }

        if isTooLarge {
            throw MojiBackupError.notBackup
        }
        guard coordinationError == nil, let contents else {
            throw MojiBackupError.unreadable
        }
        return contents
    }

    private static func defaultSafetyDirectory() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("MojiSafetyCopy", isDirectory: true)
    }

    private static func bundleVersion() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
