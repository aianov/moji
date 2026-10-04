import Foundation

enum MojiWordPartOfSpeech: String, CaseIterable, Sendable {
    case noun
    case nounSuru = "noun_suru"
    case prenominal = "adj_pn"
    case pronoun
    case verb
    case adjectiveI = "adj_i"
    case adjectiveNa = "adj_na"
    case adverb
    case particle
    case conjunction
    case interjection
    case expression
    case counter
    case number
    case prefix
    case suffix
    case auxiliary
}

struct MojiWordToken: Hashable, Sendable {
    let surface: String
    let reading: String?
    var isTarget = false
    var romajiOverride: String? = nil

    var spoken: String {
        reading ?? surface
    }

    var hasKanji: Bool {
        surface.contains { MojiFurigana.isKanji($0) }
    }

    var isPunctuation: Bool {
        !surface.isEmpty && surface.allSatisfy { MojiWordToken.punctuation.contains($0) }
    }

    static let punctuation: Set<Character> = [
        "。", "、", "！", "？", "!", "?", ".", ",", "「", "」", "『", "』", "（", "）", "(", ")",
        "・", "…", "〜", "～", "：", ":", "；", ";", "　", " ", "“", "”", "\"", "'"
    ]
}

struct MojiWordSentenceSource: Hashable, Sendable {
    var tatoebaID: Int?
    var speaker: String?
    var license: String?
}

struct MojiWordSentence: Hashable, Sendable {
    let tokens: [MojiWordToken]
    let russian: String
    let english: String
    var audioID: String? = nil
    var source: MojiWordSentenceSource? = nil

    var text: String {
        tokens.map(\.surface).joined()
    }

    var spoken: String {
        tokens.map(\.spoken).joined()
    }

    var reading: String {
        tokens.filter { !$0.isPunctuation }.map(\.spoken).joined()
    }

    func translation(in language: MojiLanguage) -> String {
        switch language {
        case .en: english
        case .ru: russian.isEmpty ? english : russian
        }
    }
}

struct MojiWord: Identifiable, Sendable {
    let id: String
    let written: String
    let reading: String
    let romaji: String
    let english: String
    let russian: String
    let rank: Int
    let section: Int
    let partOfSpeech: MojiWordPartOfSpeech?
    let sentences: [MojiWordSentence]

    func meaning(in language: MojiLanguage) -> String {
        switch language {
        case .en: english
        case .ru: russian.isEmpty ? english : russian
        }
    }

    var hasKanji: Bool {
        written.contains { MojiFurigana.isKanji($0) }
    }

    var kanji: [String] {
        var seen: Set<Character> = []
        var result: [String] = []
        for character in written where MojiFurigana.isKanji(character) && seen.insert(character).inserted {
            result.append(String(character))
        }
        return result
    }

    var token: MojiWordToken {
        MojiWordToken(surface: written, reading: hasKanji ? reading : nil, isTarget: true)
    }

    func sentence(at index: Int) -> MojiWordSentence? {
        guard !sentences.isEmpty else { return nil }
        let position = ((index % sentences.count) + sentences.count) % sentences.count
        return sentences[position]
    }
}

extension MojiWord: Hashable {
    static func == (lhs: MojiWord, rhs: MojiWord) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct MojiWordSection: Identifiable, Hashable, Sendable {
    let number: Int
    let wordIDs: [String]
    let first: Int
    let last: Int

    var id: Int { number }

    var count: Int {
        wordIDs.count
    }
}

struct MojiWordCredit: Hashable, Sendable {
    let english: String
    let russian: String

    func text(in language: MojiLanguage) -> String {
        switch language {
        case .en: english
        case .ru: russian.isEmpty ? english : russian
        }
    }
}
