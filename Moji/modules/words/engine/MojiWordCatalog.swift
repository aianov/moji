import Foundation

struct MojiWordDeckFile: Decodable {
    let version: Int
    let credits: [MojiWordCreditRecord]
    let words: [MojiWordRecord]

    enum CodingKeys: String, CodingKey {
        case version
        case credits
        case words
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? container.decodeIfPresent(Int.self, forKey: .version)) ?? 1
        credits = (try? container.decodeIfPresent(MojiLossyArray<MojiWordCreditRecord>.self, forKey: .credits))?.elements ?? []
        words = try container.decode(MojiLossyArray<MojiWordRecord>.self, forKey: .words).elements
    }
}

struct MojiWordCreditRecord: Codable, Sendable {
    let en: String
    let ru: String?
}

struct MojiWordRecord: Codable, Sendable {
    let id: String
    let w: String
    let r: String
    let en: String
    let ru: String?
    let rank: Int
    let sec: Int?
    let pos: String?
    let rm: String?
    let ex: MojiLossyArray<MojiWordSentenceRecord>?
}

struct MojiWordSentenceRecord: Codable, Sendable {
    let ja: String
    let ru: String?
    let en: String?
    let audio: String?
    let tatoeba: Int?
    let by: String?
    let lic: String?
}

enum MojiWordDeckParser {
    static func tokens(_ text: String) -> [MojiWordToken]? {
        var tokens: [MojiWordToken] = []
        for piece in text.split(separator: "|", omittingEmptySubsequences: false) {
            guard let token = token(String(piece)) else { return nil }
            tokens.append(token)
        }
        return tokens.isEmpty ? nil : tokens
    }

    static func token(_ piece: String) -> MojiWordToken? {
        var rest = Substring(piece)
        var isTarget = false
        if rest.hasPrefix("*") {
            isTarget = true
            rest = rest.dropFirst()
        }
        var romaji: String?
        if rest.hasSuffix(")"), let open = rest.lastIndex(of: "(") {
            romaji = String(rest[rest.index(after: open)..<rest.index(before: rest.endIndex)])
            rest = rest[..<open]
        }
        var reading: String?
        if rest.hasSuffix("]"), let open = rest.lastIndex(of: "[") {
            reading = String(rest[rest.index(after: open)..<rest.index(before: rest.endIndex)])
            rest = rest[..<open]
        }
        let surface = String(rest)
        guard !surface.isEmpty,
              !surface.contains(where: { "[]()*".contains($0) }),
              reading?.isEmpty != true,
              romaji?.isEmpty != true else {
            return nil
        }
        return MojiWordToken(
            surface: surface,
            reading: reading,
            isTarget: isTarget,
            romajiOverride: romaji
        )
    }

    static func format(_ tokens: [MojiWordToken]) -> String {
        tokens.map { token in
            var piece = token.isTarget ? "*" : ""
            piece += token.surface
            if let reading = token.reading {
                piece += "[\(reading)]"
            }
            if let romaji = token.romajiOverride {
                piece += "(\(romaji))"
            }
            return piece
        }
        .joined(separator: "|")
    }

    static func partOfSpeech(_ raw: String?) -> MojiWordPartOfSpeech? {
        raw.flatMap(MojiWordPartOfSpeech.init(rawValue:))
    }
}

final class MojiWordCatalog: Sendable {
    static let resourceName = "moji-word-deck"
    static let resourceExtension = "json"
    static let sectionSize = 100

    static let empty = MojiWordCatalog(words: [], credits: [])

    let words: [MojiWord]
    let sections: [MojiWordSection]
    let credits: [MojiWordCredit]
    let search: MojiWordSearch

    private let byID: [String: MojiWord]
    private let positionByID: [String: Int]
    private let shuffledPositionByID: [String: Int]

    init(words source: [MojiWord], credits: [MojiWordCredit]) {
        var seen: Set<String> = []
        let words = source
            .sorted { lhs, rhs in
                lhs.rank != rhs.rank ? lhs.rank < rhs.rank : lhs.id < rhs.id
            }
            .filter { seen.insert($0.id).inserted }

        var byID: [String: MojiWord] = [:]
        var positionByID: [String: Int] = [:]
        var membersBySection: [Int: [String]] = [:]
        var bounds: [Int: (first: Int, last: Int)] = [:]
        for (index, word) in words.enumerated() {
            byID[word.id] = word
            positionByID[word.id] = index
            membersBySection[word.section, default: []].append(word.id)
            let position = index + 1
            let current = bounds[word.section] ?? (position, position)
            bounds[word.section] = (min(current.first, position), max(current.last, position))
        }

        let shuffled = words
            .map { ($0.id, MojiWordFuzz.stableHash($0.id)) }
            .sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0 < $1.0 }
        var shuffledPositionByID: [String: Int] = [:]
        for (index, entry) in shuffled.enumerated() {
            shuffledPositionByID[entry.0] = index
        }

        self.words = words
        self.sections = membersBySection.keys.sorted().map { number in
            let range = bounds[number] ?? (0, 0)
            return MojiWordSection(
                number: number,
                wordIDs: membersBySection[number] ?? [],
                first: range.first,
                last: range.last
            )
        }
        self.credits = credits
        self.search = MojiWordSearch(words: words)
        self.byID = byID
        self.positionByID = positionByID
        self.shuffledPositionByID = shuffledPositionByID
    }

    var isEmpty: Bool {
        words.isEmpty
    }

    func word(_ id: String) -> MojiWord? {
        byID[id]
    }

    func position(of wordID: String) -> Int? {
        positionByID[wordID]
    }

    func shuffledPosition(of wordID: String) -> Int? {
        shuffledPositionByID[wordID]
    }

    func section(_ number: Int) -> MojiWordSection? {
        sections.first { $0.number == number }
    }

    func words(in section: MojiWordSection) -> [MojiWord] {
        section.wordIDs.compactMap { byID[$0] }
    }

    static func bundled(in bundle: Bundle = .main) -> MojiWordCatalog {
        guard let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) else {
            return .empty
        }
        return load(from: url) ?? .empty
    }

    static func load(from url: URL) -> MojiWordCatalog? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return decode(data)
    }

    static func decode(_ data: Data) -> MojiWordCatalog? {
        guard let file = try? JSONDecoder().decode(MojiWordDeckFile.self, from: data) else { return nil }
        return MojiWordCatalog(
            words: file.words.compactMap(makeWord),
            credits: file.credits.map { MojiWordCredit(english: $0.en, russian: $0.ru ?? "") }
        )
    }

    static func makeWord(_ record: MojiWordRecord) -> MojiWord? {
        let written = record.w.trimmingCharacters(in: .whitespaces)
        let reading = record.r.trimmingCharacters(in: .whitespaces)
        guard !record.id.isEmpty, !written.isEmpty, !reading.isEmpty, !record.en.isEmpty else { return nil }
        let sentences = (record.ex?.elements ?? []).compactMap(makeSentence)
        return MojiWord(
            id: record.id,
            written: written,
            reading: reading,
            romaji: record.rm ?? MojiWordRomaji.spell(reading) ?? reading,
            english: record.en,
            russian: record.ru ?? "",
            rank: record.rank,
            section: max(1, record.sec ?? ((max(1, record.rank) - 1) / sectionSize + 1)),
            partOfSpeech: MojiWordDeckParser.partOfSpeech(record.pos),
            sentences: sentences
        )
    }

    static func makeSentence(_ record: MojiWordSentenceRecord) -> MojiWordSentence? {
        guard let tokens = MojiWordDeckParser.tokens(record.ja) else { return nil }
        let english = record.en ?? ""
        let russian = record.ru ?? ""
        guard !english.isEmpty || !russian.isEmpty else { return nil }
        let source: MojiWordSentenceSource?
        if record.tatoeba != nil || record.by != nil || record.lic != nil {
            source = MojiWordSentenceSource(tatoebaID: record.tatoeba, speaker: record.by, license: record.lic)
        } else {
            source = nil
        }
        return MojiWordSentence(
            tokens: tokens,
            russian: russian,
            english: english,
            audioID: record.audio.flatMap { $0.isEmpty ? nil : $0 },
            source: source
        )
    }
}
