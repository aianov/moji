import Foundation

enum MojiAnswerChecker {
    static func isCorrect(
        chosenID: String?,
        typed: String?,
        drawn: MojiDrawnAnswer? = nil,
        question: MojiQuizQuestion,
        answer: MojiCharacter?
    ) -> Bool {
        if question.input == .drawing {
            return answer?.id == question.characterID && drawn?.isCorrect == true
        }
        guard let typed else {
            return chosenID == question.characterID
        }
        guard let answer, answer.id == question.characterID else { return false }
        return accepts(typed, for: answer, direction: question.direction)
    }

    static func accepts(
        _ typed: String,
        for answer: MojiCharacter,
        direction: MojiQuizDirection
    ) -> Bool {
        switch direction {
        case .glyphToRomaji:
            let normalized = MojiRomaji.normalize(typed)
            return !normalized.isEmpty && romajiAnswers(for: answer).contains(normalized)
        case .romajiToGlyph:
            let written = typed
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .precomposedStringWithCanonicalMapping
            return !written.isEmpty && writtenAnswers(for: answer).contains(written)
        }
    }

    static func writtenAnswers(for character: MojiCharacter) -> Set<String> {
        var accepted: Set<String> = [character.glyph.precomposedStringWithCanonicalMapping]
        guard character.script.isKanji else { return accepted }
        let readings = [character.reading].compactMap { $0 } + character.otherReadings.map(\.kana)
        for reading in readings {
            guard let open = reading.firstIndex(of: "("),
                  let close = reading.lastIndex(of: ")"),
                  open < close else {
                continue
            }
            let ending = reading[reading.index(after: open)..<close]
            accepted.insert((character.glyph + ending).precomposedStringWithCanonicalMapping)
        }
        return accepted
    }

    static func romajiAnswers(for character: MojiCharacter) -> Set<String> {
        var accepted: Set<String> = []
        let readings = [character.reading ?? character.glyph] + character.otherReadings.map(\.kana)
        for reading in readings {
            for form in forms(of: reading) {
                accepted.formUnion(MojiRomaji.spellings(of: form) ?? [])
            }
        }
        for form in forms(of: character.romaji) {
            accepted.insert(MojiRomaji.normalize(form))
        }
        if !character.script.isKanji {
            for (spelling, twin) in [("ou", "oo"), ("oo", "ou"), ("ei", "ee"), ("ee", "ei")] where accepted.contains(spelling) {
                accepted.insert(twin)
            }
        }
        accepted.remove("")
        return accepted
    }

    static func otherReading(spelledBy typed: String, for character: MojiCharacter) -> MojiReading? {
        let normalized = MojiRomaji.normalize(typed)
        guard !normalized.isEmpty, !character.otherReadings.isEmpty else { return nil }
        func spells(_ reading: String) -> Bool {
            forms(of: reading).contains { MojiRomaji.spellings(of: $0)?.contains(normalized) ?? false }
        }
        if let first = character.reading, spells(first) {
            return nil
        }
        return character.otherReadings.first { spells($0.kana) }
    }

    static func forms(of reading: String) -> [String] {
        guard let open = reading.firstIndex(of: "(") else { return [reading] }
        let stem = String(reading[..<open])
        let whole = reading.filter { $0 != "(" && $0 != ")" }
        return stem.isEmpty ? [whole] : [stem, whole]
    }
}
