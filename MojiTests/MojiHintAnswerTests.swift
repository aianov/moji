import Testing
@testable import Moji

@Suite("Hint answers")
struct MojiHintAnswerTests {
    private static func hint(_ character: MojiCharacter) -> String {
        character.romaji.filter { $0 != "(" && $0 != ")" }
    }

    @Test("Practice accepts the hint for every character in both directions")
    func practiceAcceptsEveryHint() {
        let catalog = MojiAlphabetCatalog.shared
        var rejected: [String] = []
        for script in MojiScript.allCases {
            for character in catalog.characters(script) {
                if !MojiAnswerChecker.accepts(Self.hint(character), for: character, direction: .glyphToRomaji) {
                    rejected.append("\(character.id) \(Self.hint(character))")
                }
                if !MojiAnswerChecker.accepts(character.glyph, for: character, direction: .romajiToGlyph) {
                    rejected.append("\(character.id) \(character.glyph)")
                }
            }
        }
        #expect(rejected.isEmpty, "\(rejected.prefix(30))")
    }

    @Test("Lessons and practice accept the same romaji for every character")
    func lessonsAndPracticeAgree() {
        let catalog = MojiAlphabetCatalog.shared
        var mismatched: [String] = []
        for script in MojiScript.allCases {
            for character in catalog.characters(script) {
                for spelling in MojiAnswerChecker.romajiAnswers(for: character)
                where !MojiLearnGrading.accepts(spelling, characters: [character], allowsOtherReadings: true) {
                    mismatched.append("lessons reject \(character.id) \(spelling)")
                }
                for spelling in MojiLearnGrading.spellings(of: character, allowsOtherReadings: true)
                where !MojiAnswerChecker.accepts(spelling, for: character, direction: .glyphToRomaji) {
                    mismatched.append("practice rejects \(character.id) \(spelling)")
                }
            }
        }
        #expect(mismatched.isEmpty, "\(mismatched.prefix(30))")
    }

    @Test("Long vowels can be typed doubled, with a macron or as written in kana")
    func longVowelSpellings() throws {
        let catalog = MojiAlphabetCatalog.shared
        let winter = try #require(MojiScript.allCases.flatMap { catalog.characters($0) }.first { $0.glyph == "冬" })
        try #require(winter.otherReadings.contains { $0.kana == "とう" })
        for typed in ["fuyu", "tou", "too", "tō", "tô"] {
            #expect(MojiAnswerChecker.accepts(typed, for: winter, direction: .glyphToRomaji), "\(typed)")
            #expect(MojiLearnGrading.accepts(typed, characters: [winter], allowsOtherReadings: true), "\(typed)")
        }
        let card = "カード"
        #expect(MojiRomaji.spellings(of: card)?.contains("kaado") == true)
        #expect(MojiLearnGrading.normalizedRomaji("ka-do") == "kaado")
    }

    @Test("Lessons accept the hint for every character and every kana pair")
    func lessonsAcceptEveryHint() {
        let catalog = MojiAlphabetCatalog.shared
        var rejected: [String] = []
        for script in MojiScript.allCases {
            let pool = catalog.characters(script)
            for character in pool {
                if !MojiLearnGrading.accepts(Self.hint(character), characters: [character], allowsOtherReadings: true) {
                    rejected.append("\(character.id) \(Self.hint(character))")
                }
            }
            guard !script.isKanji else { continue }
            for first in pool {
                for second in pool where second.id != first.id {
                    let word = [first, second]
                    let typed = word.map(Self.hint).joined()
                    if !MojiLearnGrading.gradeTyped(typed, characters: word).allSatisfy({ $0 }) {
                        rejected.append("\(first.id)+\(second.id) \(typed)")
                    }
                }
            }
        }
        #expect(rejected.isEmpty, "\(rejected.prefix(30))")
    }
}
