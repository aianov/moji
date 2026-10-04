import Foundation

struct MojiWordSearch: Sendable {
    private struct Entry: Sendable {
        let id: String
        let written: String
        let reading: String
        let romajiKey: String
        let meanings: [String]
        let meaningWords: Set<String>
        let primarySynonyms: Set<String>
        let synonyms: Set<String>
        let primaryWords: Set<String>
    }

    private let entries: [Entry]

    init(words: [MojiWord]) {
        entries = words.map { word in
            let meanings = [word.english, word.russian]
                .filter { !$0.isEmpty }
                .map(Self.fold)
            let senses = meanings.map(Self.senses)
            let primary = senses.compactMap(\.first).flatMap { $0 }
            return Entry(
                id: word.id,
                written: Self.written(word.written),
                reading: MojiWordRomaji.hiragana(Self.written(word.reading)),
                romajiKey: MojiWordRomaji.searchKey(word.romaji),
                meanings: meanings,
                meaningWords: Set(meanings.flatMap(Self.words)),
                primarySynonyms: Set(primary),
                synonyms: Set(senses.flatMap { $0 }.flatMap { $0 }),
                primaryWords: Set(primary.flatMap(Self.words))
            )
        }
    }

    func matches(_ query: String) -> [String] {
        let written = Self.written(query)
        guard !written.isEmpty else { return [] }

        var scored: [(score: Int, index: Int)] = []
        if written.unicodeScalars.contains(where: Self.isJapanese) {
            let kana = MojiWordRomaji.hiragana(written)
            for (index, entry) in entries.enumerated() {
                if let score = Self.japaneseScore(entry, written: written, kana: kana) {
                    scored.append((score, index))
                }
            }
        } else {
            let key = MojiWordRomaji.searchKey(written)
            let folded = Self.fold(query)
            let phrase = Self.synonym(folded)
            for (index, entry) in entries.enumerated() {
                let romaji = Self.romajiScore(entry, key: key)
                let meaning = Self.meaningScore(entry, folded: folded, phrase: phrase)
                if let score = [romaji, meaning].compactMap({ $0 }).min() {
                    scored.append((score, index))
                }
            }
        }
        return scored
            .sorted { $0.score != $1.score ? $0.score < $1.score : $0.index < $1.index }
            .map { entries[$0.index].id }
    }

    private static func japaneseScore(_ entry: Entry, written: String, kana: String) -> Int? {
        if entry.written == written || entry.reading == kana {
            return 0
        }
        if entry.written.hasPrefix(written) || entry.reading.hasPrefix(kana) {
            return 1
        }
        if entry.written.contains(written) || entry.reading.contains(kana) {
            return 2
        }
        return nil
    }

    private static func romajiScore(_ entry: Entry, key: String) -> Int? {
        guard !key.isEmpty else { return nil }
        if entry.romajiKey == key {
            return 0
        }
        if entry.romajiKey.hasPrefix(key) {
            return 1
        }
        if key.count >= 3, entry.romajiKey.contains(key) {
            return 5
        }
        return nil
    }

    private static func meaningScore(_ entry: Entry, folded: String, phrase: String) -> Int? {
        guard !folded.isEmpty else { return nil }
        if entry.primarySynonyms.contains(phrase) {
            return 0
        }
        if entry.synonyms.contains(phrase) || entry.meanings.contains(folded) {
            return 1
        }
        if entry.primaryWords.contains(folded) {
            return 2
        }
        if entry.meaningWords.contains(folded) {
            return 3
        }
        if entry.meaningWords.contains(where: { $0.hasPrefix(folded) }) {
            return 4
        }
        if folded.count >= 3, entry.meanings.contains(where: { $0.contains(folded) }) {
            return 6
        }
        return nil
    }

    private static func senses(_ meaning: String) -> [[String]] {
        meaning
            .components(separatedBy: ";")
            .map { sense in
                sense.components(separatedBy: ",").map(synonym).filter { !$0.isEmpty }
            }
            .filter { !$0.isEmpty }
    }

    private static func synonym(_ text: String) -> String {
        var result = ""
        var depth = 0
        for character in text {
            if character == "(" {
                depth += 1
            } else if character == ")" {
                depth = max(0, depth - 1)
            } else if depth == 0 {
                result.append(character)
            }
        }
        var trimmed = result
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        for article in ["to ", "a ", "an ", "the "] where trimmed.hasPrefix(article) {
            trimmed.removeFirst(article.count)
            break
        }
        return trimmed.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
    }

    private static func written(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.precomposedStringWithCompatibilityMapping.unicodeScalars
        where !scalar.properties.isWhitespace {
            scalars.append(scalar)
        }
        return String(scalars)
    }

    private static func fold(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    private static func words(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static func isJapanese(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3005, 0x3040...0x30FF, 0x31F0...0x31FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF: true
        default: false
        }
    }
}
