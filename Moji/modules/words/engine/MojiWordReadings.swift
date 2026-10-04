import Foundation

struct MojiWordReadingDictionary: Sendable {
    static let empty = MojiWordReadingDictionary(entries: [:])
    static let mergeLimit = 4

    private let entries: [String: [String]]

    private init(entries: [String: [String]]) {
        self.entries = entries
    }

    init(catalog: MojiWordCatalog) {
        var entries: [String: [String]] = [:]
        for word in catalog.words where word.hasKanji && !word.reading.isEmpty {
            let reading = MojiWordRomaji.hiragana(word.reading)
            guard reading.allSatisfy(MojiWordRomaji.isKana) else { continue }
            if entries[word.written]?.contains(reading) != true {
                entries[word.written, default: []].append(reading)
            }
        }
        self.entries = entries
    }

    var isEmpty: Bool {
        entries.isEmpty
    }

    func usual(_ written: String) -> String? {
        entries[written]?.first
    }

    func only(_ written: String) -> String? {
        guard let readings = entries[written], readings.count == 1 else { return nil }
        return readings[0]
    }
}

enum MojiWordReadings {
    struct Piece: Equatable, Sendable {
        let surface: String
        let reading: String?

        var hasKanji: Bool {
            surface.contains(where: MojiFurigana.isKanji)
        }
    }

    static func pieces(of text: String) -> [Piece] {
        let source = text as NSString
        let length = source.length
        guard length > 0 else { return [] }
        guard let tokenizer = CFStringTokenizerCreate(
            kCFAllocatorDefault,
            text as CFString,
            CFRange(location: 0, length: length),
            kCFStringTokenizerUnitWordBoundary,
            Locale(identifier: "ja") as CFLocale
        ) else {
            return [Piece(surface: text, reading: nil)]
        }

        var pieces: [Piece] = []
        var cursor = 0
        while !CFStringTokenizerAdvanceToNextToken(tokenizer).isEmpty {
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            guard range.location != kCFNotFound, range.length > 0, range.location >= cursor,
                  range.location + range.length <= length else { continue }
            if range.location > cursor {
                pieces.append(Piece(surface: source.substring(with: NSRange(location: cursor, length: range.location - cursor)), reading: nil))
            }
            let surface = source.substring(with: NSRange(location: range.location, length: range.length))
            let latin = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String
            pieces.append(Piece(surface: surface, reading: kanaReading(of: surface, latin: latin)))
            cursor = range.location + range.length
        }
        if cursor < length {
            pieces.append(Piece(surface: source.substring(from: cursor), reading: nil))
        }
        return pieces
    }

    static func reading(of text: String, dictionary: MojiWordReadingDictionary = .empty) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let known = dictionary.usual(trimmed) {
            return known
        }
        var result = ""
        for token in tokens(of: trimmed, dictionary: dictionary) {
            if token.hasKanji {
                guard let reading = token.reading else { return "" }
                result += reading
            } else if token.surface.allSatisfy(MojiWordRomaji.isKana) {
                result += MojiWordRomaji.hiragana(token.surface)
            }
        }
        return result
    }

    static func tokens(
        of text: String,
        fixes: [String: String] = [:],
        dictionary: MojiWordReadingDictionary = .empty
    ) -> [MojiWordToken] {
        let pieces = pieces(of: text)
        var tokens: [MojiWordToken] = []
        var index = 0
        while index < pieces.count {
            if let merged = compound(in: pieces, from: index, dictionary: dictionary) {
                tokens.append(MojiWordToken(surface: merged.surface, reading: fix(merged.surface, in: fixes) ?? merged.reading))
                index += merged.count
                continue
            }
            let piece = pieces[index]
            if piece.hasKanji {
                let reading = fix(piece.surface, in: fixes) ?? dictionary.only(piece.surface) ?? piece.reading
                tokens.append(MojiWordToken(surface: piece.surface, reading: reading))
            } else {
                tokens.append(MojiWordToken(surface: piece.surface, reading: nil))
            }
            index += 1
        }
        return tokens
    }

    static func markingTarget(_ tokens: [MojiWordToken], word: String) -> [MojiWordToken] {
        var marked = tokens
        for index in marked.indices {
            marked[index].isTarget = false
        }
        let text = tokens.map(\.surface).joined()
        for candidate in targetCandidates(word) {
            guard let range = text.range(of: candidate) else { continue }
            let start = text.utf16.distance(from: text.startIndex, to: range.lowerBound)
            let end = text.utf16.distance(from: text.startIndex, to: range.upperBound)
            var offset = 0
            for index in marked.indices {
                let length = marked[index].surface.utf16.count
                if offset < end, offset + length > start {
                    marked[index].isTarget = true
                }
                offset += length
            }
            return marked
        }
        return marked
    }

    static func normalized(_ reading: String) -> String {
        let compact = reading.filter { !$0.isWhitespace }
        guard !compact.isEmpty else { return "" }
        let kana = compact.contains { $0.isASCII && $0.isLetter }
            ? hiragana(fromLatin: compact.lowercased())
            : compact
        return MojiWordRomaji.hiragana(kana.precomposedStringWithCanonicalMapping)
    }

    static func hiragana(fromLatin text: String) -> String {
        let mutable = NSMutableString(string: text)
        CFStringTransform(mutable as CFMutableString, nil, kCFStringTransformLatinHiragana, false)
        return mutable as String
    }

    private static func fix(_ surface: String, in fixes: [String: String]) -> String? {
        fixes[surface].flatMap { $0.isEmpty ? nil : $0 }
    }

    private static func compound(
        in pieces: [Piece],
        from start: Int,
        dictionary: MojiWordReadingDictionary
    ) -> (surface: String, reading: String, count: Int)? {
        guard !dictionary.isEmpty else { return nil }
        let longest = min(MojiWordReadingDictionary.mergeLimit, pieces.count - start)
        guard longest >= 2 else { return nil }
        for count in stride(from: longest, through: 2, by: -1) {
            let surface = pieces[start..<(start + count)].map(\.surface).joined()
            guard surface.contains(where: MojiFurigana.isKanji), let reading = dictionary.usual(surface) else { continue }
            return (surface, reading, count)
        }
        return nil
    }

    private static func kanaReading(of surface: String, latin: String?) -> String? {
        guard surface.contains(where: MojiFurigana.isKanji), let latin, !latin.isEmpty else { return nil }
        let kana = MojiWordRomaji.hiragana(hiragana(fromLatin: latin))
        guard !kana.isEmpty, kana.allSatisfy(MojiWordRomaji.isKana) else { return nil }
        return kana
    }

    private static func targetCandidates(_ word: String) -> [String] {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return [] }
        var candidates = [clean]
        var stem = clean
        while stem.count > 1, let last = stem.last, MojiWordRomaji.isKana(last) {
            stem.removeLast()
            if stem.contains(where: MojiFurigana.isKanji) {
                candidates.append(stem)
            }
        }
        return candidates
    }
}
