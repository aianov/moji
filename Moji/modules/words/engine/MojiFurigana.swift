import Foundation

struct MojiRubySegment: Hashable, Sendable {
    let base: String
    let ruby: String?
}

enum MojiFurigana {
    static func isKanji(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3005, 0x3007, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2FA1F: true
            default: false
            }
        }
    }

    static func segments(
        surface: String,
        reading: String?,
        catalog: MojiAlphabetCatalog? = nil
    ) -> [MojiRubySegment] {
        guard let reading, !reading.isEmpty, surface.contains(where: needsRuby) else {
            return [MojiRubySegment(base: surface, ruby: nil)]
        }
        let runs = makeRuns(surface)
        let target = Array(MojiWordRomaji.hiragana(reading.precomposedStringWithCanonicalMapping))
        guard let spans = match(runs, at: 0, in: target, from: 0) else {
            return [MojiRubySegment(base: surface, ruby: reading)]
        }

        var result: [MojiRubySegment] = []
        for (run, span) in zip(runs, spans) {
            guard run.needsRuby else {
                result.append(MojiRubySegment(base: run.text, ruby: nil))
                continue
            }
            let ruby = String(span)
            if let catalog, run.text.count > 1, let split = splitPerCharacter(run.text, ruby: ruby, catalog: catalog) {
                result += split
            } else {
                result.append(MojiRubySegment(base: run.text, ruby: ruby))
            }
        }
        return result
    }

    static func aligns(surface: String, reading: String) -> Bool {
        let runs = makeRuns(surface)
        let target = Array(MojiWordRomaji.hiragana(reading.precomposedStringWithCanonicalMapping))
        return match(runs, at: 0, in: target, from: 0) != nil
    }

    static func readingCandidates(of glyph: Character, catalog: MojiAlphabetCatalog) -> [String] {
        guard let character = catalog.character("j-\(glyph)") else { return [] }
        var bases: [String] = []
        let readings = [character.reading].compactMap { $0 } + character.otherReadings.map(\.kana)
        for reading in readings {
            let hiragana = MojiWordRomaji.hiragana(reading)
            if let open = hiragana.firstIndex(of: "(") {
                bases.append(String(hiragana[..<open]))
            }
            bases.append(hiragana.filter { $0 != "(" && $0 != ")" })
        }

        var seen: Set<String> = []
        var result: [String] = []
        func add(_ candidate: String) {
            guard !candidate.isEmpty, seen.insert(candidate).inserted else { return }
            result.append(candidate)
        }
        for base in bases {
            add(base)
            for voiced in voicedForms(of: base) {
                add(voiced)
                add(geminated(voiced))
            }
            add(geminated(base))
        }
        return result
    }

    private struct Run {
        var text: String
        let needsRuby: Bool
    }

    private static func needsRuby(_ character: Character) -> Bool {
        !MojiWordRomaji.isKana(character)
    }

    private static func makeRuns(_ surface: String) -> [Run] {
        var runs: [Run] = []
        for character in surface {
            let ruby = needsRuby(character)
            if let last = runs.last, last.needsRuby == ruby {
                runs[runs.count - 1].text.append(character)
            } else {
                runs.append(Run(text: String(character), needsRuby: ruby))
            }
        }
        return runs
    }

    private static func match(
        _ runs: [Run],
        at index: Int,
        in reading: [Character],
        from position: Int
    ) -> [ArraySlice<Character>]? {
        guard index < runs.count else {
            return position == reading.count ? [] : nil
        }
        let run = runs[index]
        if run.needsRuby {
            var end = position + 1
            while end <= reading.count {
                if let rest = match(runs, at: index + 1, in: reading, from: end) {
                    return [reading[position..<end]] + rest
                }
                end += 1
            }
            return nil
        }
        let literal = Array(MojiWordRomaji.hiragana(run.text))
        let end = position + literal.count
        guard end <= reading.count, Array(reading[position..<end]) == literal,
              let rest = match(runs, at: index + 1, in: reading, from: end) else {
            return nil
        }
        return [reading[position..<end]] + rest
    }

    private static func splitPerCharacter(
        _ text: String,
        ruby: String,
        catalog: MojiAlphabetCatalog
    ) -> [MojiRubySegment]? {
        let characters = Array(text)
        guard characters.allSatisfy(isKanji) else { return nil }
        let target = Array(ruby)

        var options: [[String]] = []
        for (index, character) in characters.enumerated() {
            let source = character == "々" && index > 0 ? characters[index - 1] : character
            let candidates = readingCandidates(of: source, catalog: catalog)
            guard !candidates.isEmpty else { return nil }
            options.append(candidates.sorted { $0.count > $1.count })
        }

        func solve(_ index: Int, _ position: Int) -> [String]? {
            guard index < characters.count else {
                return position == target.count ? [] : nil
            }
            for candidate in options[index] {
                let end = position + candidate.count
                guard end <= target.count, String(target[position..<end]) == candidate,
                      let rest = solve(index + 1, end) else { continue }
                return [candidate] + rest
            }
            return nil
        }

        guard let parts = solve(0, 0) else { return nil }
        return zip(characters, parts).map { MojiRubySegment(base: String($0), ruby: $1) }
    }

    private static func voicedForms(of reading: String) -> [String] {
        guard let first = reading.first, let forms = voicing[first] else { return [] }
        let tail = reading.dropFirst()
        return forms.map { String($0) + tail }
    }

    private static func geminated(_ reading: String) -> String {
        guard reading.count >= 2, let last = reading.last, "つちくき".contains(last) else { return reading }
        return String(reading.dropLast()) + "っ"
    }

    private static let voicing: [Character: [Character]] = [
        "か": ["が"], "き": ["ぎ"], "く": ["ぐ"], "け": ["げ"], "こ": ["ご"],
        "さ": ["ざ"], "し": ["じ"], "す": ["ず"], "せ": ["ぜ"], "そ": ["ぞ"],
        "た": ["だ"], "ち": ["ぢ", "じ"], "つ": ["づ", "ず"], "て": ["で"], "と": ["ど"],
        "は": ["ば", "ぱ"], "ひ": ["び", "ぴ"], "ふ": ["ぶ", "ぷ"], "へ": ["べ", "ぺ"], "ほ": ["ぼ", "ぽ"]
    ]
}
