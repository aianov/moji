import Foundation

struct MojiCharacterSearch: Sendable {
    private let orderedIDs: [String]
    private let idsByGlyph: [String: Set<String>]
    private let idsByKana: [String: Set<String>]
    private let idsByRomaji: [String: Set<String>]

    init(characters: [MojiCharacter]) {
        var idsByGlyph: [String: Set<String>] = [:]
        var idsByKana: [String: Set<String>] = [:]
        var idsByRomaji: [String: Set<String>] = [:]
        for character in characters {
            let glyph = Self.written(character.glyph)
            idsByGlyph[glyph, default: []].insert(character.id)
            idsByKana[Self.hiragana(glyph), default: []].insert(character.id)
            for spelling in MojiAnswerChecker.romajiAnswers(for: character) {
                idsByRomaji[spelling, default: []].insert(character.id)
            }
        }
        self.orderedIDs = characters.map(\.id)
        self.idsByGlyph = idsByGlyph
        self.idsByKana = idsByKana
        self.idsByRomaji = idsByRomaji
    }

    func matches(_ query: String) -> [String] {
        let found = matchingIDs(query)
        guard !found.isEmpty else { return [] }
        return orderedIDs.filter(found.contains)
    }

    private func matchingIDs(_ query: String) -> Set<String> {
        let written = Self.written(query)
        guard !written.isEmpty else { return [] }
        if let ids = idsByGlyph[written] {
            return ids
        }
        guard written.unicodeScalars.contains(where: Self.isJapanese) else {
            return idsByRomaji[MojiRomaji.normalize(written)] ?? []
        }
        if let ids = idsByKana[Self.hiragana(written)] {
            return ids
        }
        guard let spellings = MojiRomaji.spellings(of: written) else { return [] }
        var ids: Set<String> = []
        for spelling in spellings where !spelling.isEmpty {
            ids.formUnion(idsByRomaji[spelling] ?? [])
        }
        return ids
    }

    private static func written(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.precomposedStringWithCompatibilityMapping.unicodeScalars
        where !scalar.properties.isWhitespace {
            scalars.append(scalar)
        }
        return String(scalars)
    }

    private static func hiragana(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if (0x30A1...0x30F6).contains(scalar.value),
               let converted = Unicode.Scalar(scalar.value - 0x60) {
                scalars.append(converted)
            } else {
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    private static func isJapanese(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3005, 0x3040...0x30FF, 0x31F0...0x31FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF: true
        default: false
        }
    }
}

extension MojiAlphabetCatalog {
    func searchPages(_ script: MojiScript, from page: MojiPage) -> [MojiPage] {
        let pages = pages(script)
        let start = pages.firstIndex(of: page) ?? pages.startIndex
        return Array(pages[start...] + pages[..<start])
    }
}
