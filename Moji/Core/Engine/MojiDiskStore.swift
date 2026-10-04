import Foundation
import OSLog

struct MojiDiskKey: Hashable, Sendable {
    let namespace: String
    let name: String

    var fileName: String {
        "\(namespace).\(name).json"
    }
}

private struct MojiDiskEnvelope<Value: Codable>: Codable {
    let version: Int
    let savedAt: Date
    let value: Value
}

actor MojiDiskStore {
    static let shared = MojiDiskStore()

    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "com.aianov.moji", category: "disk")
    private var memory: [MojiDiskKey: Data] = [:]

    init(directory: URL? = nil) {
        self.directory = directory ?? Self.defaultDirectory()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        self.decoder = decoder
    }

    func read<Value: Codable & Sendable>(
        _ type: Value.Type,
        key: MojiDiskKey,
        version: Int
    ) -> Value? {
        guard let data = data(for: key) else { return nil }

        do {
            let envelope = try decoder.decode(MojiDiskEnvelope<Value>.self, from: data)
            guard envelope.version == version else {
                logger.notice("\(key.fileName, privacy: .public) has version \(envelope.version), expected \(version)")
                return nil
            }
            return envelope.value
        } catch {
            logger.error("\(key.fileName, privacy: .public) is unreadable: \(error.localizedDescription, privacy: .public)")
            quarantine(key)
            return nil
        }
    }

    func write<Value: Codable & Sendable>(
        _ value: Value,
        key: MojiDiskKey,
        version: Int
    ) {
        do {
            let envelope = MojiDiskEnvelope(
                version: version,
                savedAt: Date(),
                value: value
            )
            let data = try encoder.encode(envelope)
            try ensureDirectory()
            try data.write(
                to: fileURL(for: key),
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
            memory[key] = data
        } catch {
            logger.error("\(key.fileName, privacy: .public) write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func remove(_ key: MojiDiskKey) {
        memory[key] = nil
        let url = fileURL(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            logger.error("\(key.fileName, privacy: .public) remove failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func clearMemory() {
        memory = [:]
    }

    func withExclusiveAccess<T: Sendable>(_ body: @Sendable (URL) throws -> T) throws -> T {
        defer { memory = [:] }
        return try body(directory)
    }

    private func data(for key: MojiDiskKey) -> Data? {
        if let cached = memory[key] {
            return cached
        }
        guard let stored = try? Data(contentsOf: fileURL(for: key)) else { return nil }
        memory[key] = stored
        return stored
    }

    private func quarantine(_ key: MojiDiskKey) {
        memory[key] = nil
        let stamp = Int(Date().timeIntervalSince1970)
        let target = directory.appendingPathComponent(
            "\(key.namespace).\(key.name).corrupt-\(stamp).json",
            isDirectory: false
        )
        try? FileManager.default.moveItem(at: fileURL(for: key), to: target)
    }

    private func ensureDirectory() throws {
        guard !FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    private func fileURL(for key: MojiDiskKey) -> URL {
        directory.appendingPathComponent(key.fileName, isDirectory: false)
    }

    private static func defaultDirectory() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Moji", isDirectory: true)
    }
}
