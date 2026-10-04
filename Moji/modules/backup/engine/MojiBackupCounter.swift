import Foundation

enum MojiBackupCounter {
    static let progressFile = MojiDiskKey(namespace: "practice", name: "progress").fileName
    static let wordCardsFile = MojiDiskKey(namespace: "words", name: "cards").fileName
    static let ownWordsFile = MojiDiskKey(namespace: "words", name: "mine").fileName
    static let notesFile = MojiNoteResourceRepository.libraryKey.fileName

    static func counts(of files: [MojiBackupFile]) -> MojiBackupCounts {
        var contents: [String: Data] = [:]
        for file in files {
            contents[file.name] = file.contents
        }

        let progress = value([String: MojiCharacterProgress].self, in: contents[progressFile]) ?? [:]
        let cards = value(MojiWordLossyMap<MojiWordCard>.self, in: contents[wordCardsFile])?.values ?? [:]

        return MojiBackupCounts(
            characters: progress.values.filter { $0.seen > 0 || $0.strength > 0 || $0.isWritten }.count,
            wordCards: cards.values.filter { !$0.isNew }.count,
            ownCards: entries(in: contents[ownWordsFile]),
            notes: value(MojiNoteLibrary.self, in: contents[notesFile])?.sanitized().notes.count
        )
    }

    private static func value<Value: Decodable>(_ type: Value.Type, in data: Data?) -> Value? {
        guard let data else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(MojiBackupEnvelope<Value>.self, from: data).value
    }

    private static func entries(in data: Data?) -> Int? {
        guard let data,
              let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return (envelope["value"] as? [Any])?.count
    }
}

private struct MojiBackupEnvelope<Value: Decodable>: Decodable {
    let value: Value
}
