import Foundation

enum MojiLearnGrading {
    static func normalizedRomaji(_ text: String) -> String {
        var result = ""
        for character in text.lowercased() {
            switch character {
            case "ā", "â": result += "aa"
            case "ī", "î": result += "ii"
            case "ū", "û": result += "uu"
            case "ē", "ê": result += "ee"
            case "ō", "ô": result += "oo"
            case "-", "ー":
                if let last = result.last, "aiueo".contains(last) {
                    result.append(last)
                }
            default:
                if character.isASCII, character.isLetter {
                    result.append(character)
                }
            }
        }
        return result
    }

    static func spellings(of character: MojiCharacter, allowsOtherReadings: Bool = false) -> [String] {
        var result: [String] = []
        func add(_ spelling: String) {
            guard !spelling.isEmpty, !result.contains(spelling) else { return }
            result.append(spelling)
        }

        let base = normalizedRomaji(character.romaji)
        add(base)
        add(kunrei(base))
        add(imeSpelling(base))

        if let open = character.romaji.firstIndex(of: "(") {
            let stem = normalizedRomaji(String(character.romaji[..<open]))
            add(stem)
            add(kunrei(stem))
        }

        if character.script.isKanji {
            var readings = character.reading.map { [$0] } ?? []
            if allowsOtherReadings {
                readings += character.otherReadings.map(\.kana)
            }
            for reading in readings {
                for form in MojiAnswerChecker.forms(of: reading) {
                    for spelling in MojiRomaji.spellings(of: form) ?? [] {
                        add(normalizedRomaji(spelling))
                    }
                }
            }
        }

        if !character.script.isKanji {
            if let suffix = character.id.split(separator: "-").last {
                add(normalizedRomaji(String(suffix)))
            }
            for spelling in MojiRomaji.spellings(of: character.glyph) ?? [] where !spelling.contains("-") {
                add(normalizedRomaji(spelling))
            }
        }

        switch base {
        case "wo": add("o")
        case "n": add("nn")
        case "ou": add("oo")
        case "oo": add("ou")
        case "ei": add("ee")
        case "ee": add("ei")
        default: break
        }
        return result
    }

    static func accepts(
        _ typed: String,
        characters: [MojiCharacter],
        allowsOtherReadings: Bool = false
    ) -> Bool {
        let text = Array(normalizedRomaji(typed))
        guard !text.isEmpty, !characters.isEmpty else { return false }

        var reachable: Set<Int> = [0]
        for character in characters {
            var next: Set<Int> = []
            let candidates = spellings(of: character, allowsOtherReadings: allowsOtherReadings).map(Array.init)
            for start in reachable {
                for spelling in candidates where matches(spelling, in: text, at: start) {
                    next.insert(start + spelling.count)
                }
            }
            guard !next.isEmpty else { return false }
            reachable = next
        }
        return reachable.contains(text.count)
    }

    static func gradeTyped(
        _ typed: String,
        characters: [MojiCharacter],
        allowsOtherReadings: Bool = false
    ) -> [Bool] {
        guard !characters.isEmpty else { return [] }
        if accepts(typed, characters: characters, allowsOtherReadings: allowsOtherReadings) {
            return Array(repeating: true, count: characters.count)
        }

        let text = Array(normalizedRomaji(typed))
        var flags = Array(repeating: false, count: characters.count)

        var front = 0
        var leading = 0
        while leading < characters.count {
            let candidates = spellings(of: characters[leading], allowsOtherReadings: allowsOtherReadings)
                .map(Array.init)
                .filter { matches($0, in: text, at: front) }
            guard let longest = candidates.max(by: { $0.count < $1.count }) else { break }
            flags[leading] = true
            front += longest.count
            leading += 1
        }

        var back = text.count
        var trailing = characters.count - 1
        while trailing >= leading {
            let candidates = spellings(of: characters[trailing], allowsOtherReadings: allowsOtherReadings)
                .map(Array.init)
                .filter { $0.count <= back - front && matches($0, in: text, at: back - $0.count) }
            guard let longest = candidates.max(by: { $0.count < $1.count }) else { break }
            flags[trailing] = true
            back -= longest.count
            trailing -= 1
        }

        if flags.allSatisfy({ $0 }) {
            flags[flags.count - 1] = false
        }
        return flags
    }

    private static func matches(_ spelling: [Character], in text: [Character], at start: Int) -> Bool {
        guard start >= 0, start + spelling.count <= text.count else { return false }
        return Array(text[start..<(start + spelling.count)]) == spelling
    }

    private static func kunrei(_ hepburn: String) -> String {
        var text = hepburn
        for (from, to) in [
            ("sha", "sya"), ("shu", "syu"), ("sho", "syo"), ("shi", "si"),
            ("cha", "tya"), ("chu", "tyu"), ("cho", "tyo"), ("chi", "ti"),
            ("tsu", "tu"), ("fu", "hu"),
            ("ja", "zya"), ("ju", "zyu"), ("jo", "zyo"), ("ji", "zi")
        ] {
            text = text.replacingOccurrences(of: from, with: to)
        }
        return text
    }

    private static func imeSpelling(_ hepburn: String) -> String {
        var text = hepburn
        for (from, to) in [("ja", "jya"), ("ju", "jyu"), ("jo", "jyo")] {
            text = text.replacingOccurrences(of: from, with: to)
        }
        return text
    }
}
