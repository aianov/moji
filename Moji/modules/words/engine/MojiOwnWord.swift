import Foundation

struct MojiOwnToken: Codable, Equatable, Sendable {
    let surface: String
    let reading: String?
    let isTarget: Bool

    enum CodingKeys: String, CodingKey {
        case surface
        case reading
        case isTarget = "target"
    }

    init(surface: String, reading: String?, isTarget: Bool = false) {
        self.surface = surface
        self.reading = reading.flatMap { $0.isEmpty ? nil : $0 }
        self.isTarget = isTarget
    }

    init(_ token: MojiWordToken) {
        self.init(surface: token.surface, reading: token.reading, isTarget: token.isTarget)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let surface = try container.decode(String.self, forKey: .surface)
        guard !surface.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .surface, in: container, debugDescription: "Empty token")
        }
        self.init(
            surface: surface,
            reading: try? container.decodeIfPresent(String.self, forKey: .reading),
            isTarget: (try? container.decodeIfPresent(Bool.self, forKey: .isTarget)) ?? false
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(surface, forKey: .surface)
        try container.encodeIfPresent(reading, forKey: .reading)
        if isTarget {
            try container.encode(true, forKey: .isTarget)
        }
    }

    var token: MojiWordToken {
        MojiWordToken(surface: surface, reading: reading, isTarget: isTarget)
    }
}

enum MojiOwnWordProblem: Equatable, Sendable {
    case missingWord
    case wordNotJapanese
    case missingMeaning
}

struct MojiOwnWordInput: Equatable, Sendable {
    var written = ""
    var reading = ""
    var meaning = ""
    var sentence: [MojiWordToken] = []
    var translation = ""
    var note = ""

    var problems: [MojiOwnWordProblem] {
        let clean = cleaned()
        var problems: [MojiOwnWordProblem] = []
        if clean.written.isEmpty {
            problems.append(.missingWord)
        } else if !clean.written.contains(where: Self.isJapanese) {
            problems.append(.wordNotJapanese)
        }
        if clean.meaning.isEmpty {
            problems.append(.missingMeaning)
        }
        return problems
    }

    var isValid: Bool {
        problems.isEmpty
    }

    func cleaned() -> MojiOwnWordInput {
        let written = Self.line(self.written)
        var reading = MojiWordReadings.normalized(self.reading)
        if reading.isEmpty, !written.isEmpty, written.allSatisfy(MojiWordRomaji.isKana) {
            reading = MojiWordRomaji.hiragana(written)
        }
        return MojiOwnWordInput(
            written: written,
            reading: reading,
            meaning: meaning.trimmingCharacters(in: .whitespacesAndNewlines),
            sentence: Self.cleanSentence(sentence),
            translation: translation.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    static func isJapanese(_ character: Character) -> Bool {
        MojiFurigana.isKanji(character) || MojiWordRomaji.isKana(character)
    }

    private static func line(_ text: String) -> String {
        text.components(separatedBy: .newlines).joined().trimmingCharacters(in: .whitespaces)
    }

    private static func cleanSentence(_ tokens: [MojiWordToken]) -> [MojiWordToken] {
        var cleaned = tokens.compactMap { token -> MojiWordToken? in
            let surface = token.surface.components(separatedBy: .newlines).joined(separator: " ")
            guard !surface.isEmpty else { return nil }
            let reading = surface.contains(where: MojiFurigana.isKanji)
                ? token.reading.map(MojiWordReadings.normalized).flatMap { $0.isEmpty ? nil : $0 }
                : nil
            return MojiWordToken(surface: surface, reading: reading, isTarget: token.isTarget)
        }
        while let first = cleaned.first, first.surface.allSatisfy(\.isWhitespace) {
            cleaned.removeFirst()
        }
        while let last = cleaned.last, last.surface.allSatisfy(\.isWhitespace) {
            cleaned.removeLast()
        }
        return cleaned
    }
}

struct MojiOwnWord: Codable, Equatable, Identifiable, Sendable {
    static let idPrefix = "my-"

    let id: String
    var written: String
    var reading: String
    var meaning: String
    var sentence: [MojiOwnToken]
    var translation: String
    var note: String
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case written
        case reading
        case meaning
        case sentence
        case translation
        case note
        case createdAt
        case updatedAt
    }

    init(id: String = MojiOwnWord.makeID(), input: MojiOwnWordInput, at date: Date) {
        self.id = id
        written = input.written
        reading = input.reading
        meaning = input.meaning
        sentence = input.sentence.map(MojiOwnToken.init)
        translation = input.translation
        note = input.note
        createdAt = date
        updatedAt = date
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let written = Self.text(container, .written)
        let meaning = Self.text(container, .meaning)
        guard Self.isOwnID(id), !written.isEmpty, !meaning.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Incomplete card \(id)")
        }
        self.id = id
        self.written = written
        self.meaning = meaning
        reading = Self.text(container, .reading)
        sentence = (try? container.decodeIfPresent(MojiLossyArray<MojiOwnToken>.self, forKey: .sentence))?.elements ?? []
        translation = Self.text(container, .translation)
        note = Self.text(container, .note)
        let created = (try? container.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date(timeIntervalSince1970: 0)
        createdAt = created
        updatedAt = (try? container.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? created
    }

    static func makeID() -> String {
        idPrefix + UUID().uuidString.lowercased()
    }

    static func isOwnID(_ id: String) -> Bool {
        id.count > idPrefix.count && id.hasPrefix(idPrefix)
    }

    static func catalog(of words: [MojiOwnWord]) -> MojiWordCatalog {
        MojiWordCatalog(
            words: words.enumerated().map { $0.element.word(rank: $0.offset + 1) },
            credits: []
        )
    }

    var input: MojiOwnWordInput {
        MojiOwnWordInput(
            written: written,
            reading: reading,
            meaning: meaning,
            sentence: sentence.map(\.token),
            translation: translation,
            note: note
        )
    }

    var romaji: String {
        MojiWordRomaji.spell(reading.isEmpty ? written : reading) ?? ""
    }

    @discardableResult
    mutating func apply(_ input: MojiOwnWordInput, at date: Date) -> Bool {
        let tokens = input.sentence.map(MojiOwnToken.init)
        guard written != input.written || reading != input.reading || meaning != input.meaning
            || sentence != tokens || translation != input.translation || note != input.note else {
            return false
        }
        written = input.written
        reading = input.reading
        meaning = input.meaning
        sentence = tokens
        translation = input.translation
        note = input.note
        updatedAt = date
        return true
    }

    func word(rank: Int) -> MojiWord {
        let sentences = sentence.isEmpty
            ? []
            : [MojiWordSentence(tokens: sentence.map(\.token), russian: "", english: translation)]
        return MojiWord(
            id: id,
            written: written,
            reading: reading,
            romaji: romaji,
            english: meaning,
            russian: "",
            rank: rank,
            section: 1,
            partOfSpeech: nil,
            sentences: sentences
        )
    }

    private static func text(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String {
        ((try? container.decodeIfPresent(String.self, forKey: key)) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
