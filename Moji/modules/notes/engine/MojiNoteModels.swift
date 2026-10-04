import Foundation

struct MojiNoteFolder: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var name: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt
    }

    init(id: String, name: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        guard !id.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Empty folder id")
        }
        self.id = id
        name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
        createdAt = (try? container.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date(timeIntervalSince1970: 0)
    }
}

struct MojiNote: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var title: String
    var body: String
    var folderID: String?
    var isPinned: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case folderID
        case isPinned
        case createdAt
        case updatedAt
    }

    init(
        id: String,
        title: String,
        body: String,
        folderID: String?,
        isPinned: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.folderID = folderID
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        guard !id.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Empty note id")
        }
        self.id = id
        title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? ""
        body = (try? container.decodeIfPresent(String.self, forKey: .body)) ?? ""
        let folderID = try? container.decodeIfPresent(String.self, forKey: .folderID)
        self.folderID = folderID?.isEmpty == false ? folderID : nil
        isPinned = (try? container.decodeIfPresent(Bool.self, forKey: .isPinned)) ?? false
        let created = try? container.decodeIfPresent(Date.self, forKey: .createdAt)
        let updated = try? container.decodeIfPresent(Date.self, forKey: .updatedAt)
        let createdAt = created ?? updated ?? Date(timeIntervalSince1970: 0)
        self.createdAt = createdAt
        updatedAt = updated ?? createdAt
    }

    var isBlank: Bool {
        MojiNoteText.isBlank(title: title, body: body)
    }
}

struct MojiNoteLibrary: Codable, Equatable, Sendable {
    var folders: [MojiNoteFolder]
    var notes: [MojiNote]

    static let empty = MojiNoteLibrary(folders: [], notes: [])

    enum CodingKeys: String, CodingKey {
        case folders
        case notes
    }

    init(folders: [MojiNoteFolder], notes: [MojiNote]) {
        self.folders = folders
        self.notes = notes
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        folders = (try? container.decodeIfPresent(MojiLossyArray<MojiNoteFolder>.self, forKey: .folders))?.elements ?? []
        notes = (try? container.decodeIfPresent(MojiLossyArray<MojiNote>.self, forKey: .notes))?.elements ?? []
    }

    func sanitized() -> MojiNoteLibrary {
        var folderIDs: Set<String> = []
        var cleanFolders: [MojiNoteFolder] = []
        for folder in folders {
            guard let name = MojiNoteText.folderName(folder.name), folderIDs.insert(folder.id).inserted else { continue }
            var clean = folder
            clean.name = name
            cleanFolders.append(clean)
        }

        var byID: [String: MojiNote] = [:]
        for note in notes where !note.isBlank {
            var clean = note
            if let folderID = clean.folderID, !folderIDs.contains(folderID) {
                clean.folderID = nil
            }
            if let kept = byID[clean.id], kept.updatedAt >= clean.updatedAt {
                continue
            }
            byID[clean.id] = clean
        }
        return MojiNoteLibrary(folders: cleanFolders, notes: MojiNoteOrder.sorted(byID.values))
    }
}

struct MojiNoteCounts: Equatable, Sendable {
    let words: Int
    let characters: Int

    static let zero = MojiNoteCounts(words: 0, characters: 0)
}
