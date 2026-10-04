import CryptoKit
import Foundation

enum MojiBackupError: Error, Equatable, Sendable {
    case unreadable
    case notBackup
    case damaged
    case newerVersion
    case writeFailed
    case noSafetyCopy
}

struct MojiBackupCounts: Codable, Equatable, Sendable {
    let characters: Int
    let wordCards: Int
    let ownCards: Int?
    let notes: Int?
}

struct MojiBackupManifest: Codable, Equatable, Sendable {
    let appVersion: String
    let exportedAt: Date
    let counts: MojiBackupCounts
    let fileCount: Int
    let settingCount: Int
}

struct MojiBackupFile: Equatable, Sendable {
    let name: String
    let contents: Data

    static func digest(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

extension MojiBackupFile: Codable {
    private enum CodingKeys: String, CodingKey {
        case name
        case size
        case sha256
        case contents = "payload"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let contents = try container.decode(Data.self, forKey: .contents)
        let size = try container.decode(Int.self, forKey: .size)
        let digest = try container.decode(String.self, forKey: .sha256)
        guard size == contents.count, digest == Self.digest(of: contents) else {
            throw MojiBackupError.damaged
        }
        self.name = name
        self.contents = contents
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(contents.count, forKey: .size)
        try container.encode(Self.digest(of: contents), forKey: .sha256)
        try container.encode(contents, forKey: .contents)
    }
}

struct MojiBackupArchive: Codable, Sendable {
    let format: String
    let formatVersion: Int
    let manifest: MojiBackupManifest
    let files: [MojiBackupFile]
    let settings: Data

    private enum CodingKeys: String, CodingKey {
        case format
        case formatVersion
        case manifest
        case settings
        case files = "store"
    }
}

struct MojiBackupExport: Sendable {
    let data: Data
    let filename: String
    let manifest: MojiBackupManifest
}

struct MojiBackupPreview: Sendable {
    let data: Data
    let manifest: MojiBackupManifest
}
