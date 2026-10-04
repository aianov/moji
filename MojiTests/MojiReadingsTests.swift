import Foundation
import Testing
@testable import Moji

@Suite("Other kanji readings")
struct MojiReadingsTests {
    private let catalog = MojiAlphabetCatalog.shared

    private func kanji(_ glyph: String) throws -> MojiCharacter {
        try #require(catalog.character("j-\(glyph)"))
    }

    @Test("Kana is spelled the way the data writes romaji", arguments: [
        ("にち", "nichi"),
        ("う(まれる)", "u(mareru)"),
        ("み(っつ)", "mi(ttsu)"),
        ("みょう", "myou"),
        ("じゃく", "jaku"),
        ("ちょく", "choku"),
        ("おおやけ", "ooyake"),
        ("みんな", "minna"),
        ("コウ", "kou")
    ])
    func hepburn(kana: String, expected: String) {
        #expect(MojiHepburn.spell(kana) == expected)
    }

    @Test("Anything but kana, or a dangling small っ, has no spelling")
    func hepburnRejects() {
        #expect(MojiHepburn.spell("abc") == nil)
        #expect(MojiHepburn.spell("さっ") == nil)
        #expect(MojiHepburn.spell("") == nil)
    }

    @Test("Every listed reading reaches the catalog with its romaji")
    func everyReadingIsSpelled() {
        for (glyph, readings) in MojiAlphabetData.kanjiOtherReadings {
            let character = catalog.character("j-\(glyph)")
            #expect(character != nil, "\(glyph) is not on a page")
            #expect(character?.otherReadings.map(\.kana) == readings, "\(glyph) lost a reading")
        }
    }

    @Test("A typed reading in practice takes any reading of the kanji")
    func practiceTakesOtherReadings() throws {
        let day = try kanji("日")
        for typed in ["hi", "nichi", "NICHI", "jitsu", "ka"] {
            #expect(MojiAnswerChecker.accepts(typed, for: day, direction: .glyphToRomaji), "\(typed)")
        }
        #expect(!MojiAnswerChecker.accepts("getsu", for: day, direction: .glyphToRomaji))

        let life = try kanji("生")
        for typed in ["ikiru", "sei", "shou", "shō", "umareru", "nama"] {
            #expect(MojiAnswerChecker.accepts(typed, for: life, direction: .glyphToRomaji), "\(typed)")
        }
    }

    @Test("The answer line shows the reading that was typed")
    func typedReadingIsNamed() throws {
        let day = try kanji("日")
        #expect(MojiAnswerChecker.otherReading(spelledBy: "nichi", for: day)?.kana == "にち")
        #expect(MojiAnswerChecker.otherReading(spelledBy: "Jitsu", for: day)?.kana == "じつ")
        #expect(MojiAnswerChecker.otherReading(spelledBy: "hi", for: day) == nil)
        #expect(MojiAnswerChecker.otherReading(spelledBy: "getsu", for: day) == nil)

        let life = try kanji("生")
        #expect(MojiAnswerChecker.otherReading(spelledBy: "umareru", for: life)?.line == "う(まれる) · u(mareru)")
    }

    @Test("Learn takes other readings where the kanji is shown, not where it was heard")
    func learnTakesOtherReadingsOnlyWhenShown() throws {
        let day = try kanji("日")
        #expect(MojiLearnGrading.accepts("nichi", characters: [day], allowsOtherReadings: true))
        #expect(MojiLearnGrading.accepts("hi", characters: [day], allowsOtherReadings: true))
        #expect(!MojiLearnGrading.accepts("nichi", characters: [day], allowsOtherReadings: false))
        #expect(MojiLearnGrading.accepts("hi", characters: [day], allowsOtherReadings: false))

        let school = try kanji("校")
        #expect(MojiLearnGrading.accepts("kō", characters: [school]))
        #expect(MojiLearnGrading.accepts("kou", characters: [school]))
    }

    @Test("A right hard exercise adds two steps but is one answer seen")
    func hardExerciseSteps() {
        let before = MojiCharacterProgress(strength: 2, seen: 4, correct: 3, lastSeenAt: nil)
        let after = before.recording(correct: true, at: Date(), steps: 2)
        #expect(after.strength == 4)
        #expect(after.seen == 5)
        #expect(after.correct == 4)

        let missed = before.recording(correct: false, at: Date(), steps: 2)
        #expect(missed.strength == 0)
        #expect(missed.seen == 5)
    }
}
