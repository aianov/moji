import Foundation

enum MojiBackupCodec {
    static let format = "moji.backup"
    static let version = 1

    static func encode(_ archive: MojiBackupArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(archive)
    }

    static func decode(_ data: Data) throws -> MojiBackupArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let header = try? decoder.decode(MojiBackupHeader.self, from: data) else {
            throw data.range(of: Data(format.utf8)) == nil ? MojiBackupError.notBackup : MojiBackupError.damaged
        }
        guard header.format == format else {
            throw MojiBackupError.notBackup
        }
        guard let formatVersion = header.formatVersion, formatVersion >= 1 else {
            throw MojiBackupError.damaged
        }
        guard formatVersion <= version else {
            throw MojiBackupError.newerVersion
        }
        guard let archive = try? decoder.decode(MojiBackupArchive.self, from: data) else {
            throw MojiBackupError.damaged
        }
        try validate(archive)
        return archive
    }

    static func validate(_ archive: MojiBackupArchive) throws {
        let names = archive.files.map(\.name)
        guard Set(names).count == names.count,
              names.allSatisfy(isSafeName),
              archive.manifest.fileCount == archive.files.count,
              let settings = try? MojiBackupSettings.decode(archive.settings),
              settings.count == archive.manifest.settingCount else {
            throw MojiBackupError.damaged
        }
    }

    static func isSafeName(_ name: String) -> Bool {
        let parts = name.split(separator: "/", omittingEmptySubsequences: false)
        return !parts.isEmpty
            && !name.contains("\\")
            && !name.contains("\0")
            && parts.allSatisfy { !$0.isEmpty && !$0.hasPrefix(".") }
    }
}

private struct MojiBackupHeader: Decodable {
    let format: String?
    let formatVersion: Int?
}
