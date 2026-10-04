import Foundation
import Testing
@testable import Moji

@Suite("Typed romaji answers")
struct MojiRomajiAnswerTests {
    private let catalog = MojiAlphabetCatalog.shared

    private func kana(_ glyph: String) throws -> MojiCharacter {
        let pool = catalog.pool(.hiragana) + catalog.pool(.katakana)
        return try #require(pool.first { $0.glyph == glyph })
    }

    private func accepts(_ typed: String, _ character: MojiCharacter) -> Bool {
        MojiAnswerChecker.accepts(typed, for: character, direction: .glyphToRomaji)
    }

    @Test("Every kana takes its romaji, in any case and with spaces", arguments: [MojiScript.hiragana, .katakana])
    func everyKanaTakesItsRomaji(script: MojiScript) {
        for character in catalog.characters(script) {
            #expect(MojiRomaji.spellings(of: character.glyph) != nil, "\(character.glyph)")
            #expect(accepts(character.romaji, character), "\(character.glyph)")
            #expect(accepts(" \(character.romaji.uppercased()) ", character), "\(character.glyph)")
            #expect(accepts(character.romaji.map(String.init).joined(separator: " "), character))
            #expect(!accepts("", character))
            #expect(!accepts("  ", character))
        }
    }

    @Test("Hepburn and the other common spellings all count", arguments: [
        ("し", ["shi", "si"]), ("ち", ["chi", "ti"]), ("つ", ["tsu", "tu"]), ("ふ", ["fu", "hu"]),
        ("じ", ["ji", "zi"]), ("ぢ", ["ji", "di"]), ("づ", ["zu", "du", "dzu"]), ("を", ["o", "wo"]),
        ("ヲ", ["o", "wo"]), ("ん", ["n", "nn"]), ("ン", ["n", "nn"]),
        ("じゃ", ["ja", "jya", "zya"]), ("じゅ", ["ju", "jyu", "zyu"]), ("じょ", ["jo", "jyo", "zyo"]),
        ("しゃ", ["sha", "sya"]), ("しゅ", ["shu", "syu"]), ("しょ", ["sho", "syo"]),
        ("ちゃ", ["cha", "tya", "cya"]), ("ちゅ", ["chu", "tyu", "cyu"]), ("ちょ", ["cho", "tyo", "cyo"]),
        ("ジャ", ["ja", "jya", "zya"]), ("チョ", ["cho", "tyo", "cyo"]),
        ("っか", ["kka"]), ("っさ", ["ssa"]), ("った", ["tta"]), ("っぱ", ["ppa"]), ("ッタ", ["tta"]),
        ("ああ", ["aa", "ā", "â"]), ("いい", ["ii", "ī"]), ("うう", ["uu", "ū"]), ("ええ", ["ee", "ē"]),
        ("おお", ["oo", "ō", "Ō", "ô", "ou"]), ("えい", ["ei", "ē", "ee"]), ("おう", ["ou", "ō", "oo"]),
        ("ええ", ["ei"]), ("ぢ", ["zi"]),
        ("アー", ["aa", "ā", "a-"]), ("オー", ["oo", "ō", "o-"])
    ])
    func listedSpellings(glyph: String, spellings: [String]) throws {
        let character = try kana(glyph)
        for spelling in spellings {
            #expect(accepts(spelling, character), "\(glyph) \(spelling)")
        }
    }

    @Test("Another kana's sound is wrong, unless the two sound the same", arguments: [MojiScript.hiragana, .katakana])
    func otherSoundsAreWrong(script: MojiScript) {
        let pool = catalog.characters(script)
        let answers = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, MojiAnswerChecker.romajiAnswers(for: $0)) })
        for target in pool {
            for other in pool where other.id != target.id {
                let own = answers[target.id] ?? []
                let theirs = answers[other.id] ?? []
                guard own.isDisjoint(with: theirs) else { continue }
                for spelling in theirs {
                    #expect(!accepts(spelling, target), "\(target.glyph) took \(other.glyph)'s \(spelling)")
                }
            }
        }
    }

    @Test("Typical slips are wrong", arguments: [
        ("す", "si"), ("ち", "shi"), ("つ", "su"), ("っか", "ka"), ("ああ", "a"), ("おう", "o"),
        ("えい", "e"), ("ぬ", "n"), ("しゃ", "shiya"), ("きゃ", "kiya"), ("アー", "a"),
        ("ふ", "pu"), ("ヲ", "wa")
    ])
    func slipsAreWrong(glyph: String, typed: String) throws {
        #expect(!accepts(typed, try kana(glyph)))
    }

    @Test("A kanji takes its reading, with or without the bracketed ending", arguments: MojiKanjiTheme.allCases)
    func kanjiReadings(theme: MojiKanjiTheme) {
        for kanji in catalog.pool(.kanji(theme)) {
            let romajiForms = MojiAnswerChecker.forms(of: kanji.romaji)
            for form in romajiForms {
                #expect(accepts(form, kanji), "\(kanji.glyph) \(form)")
            }
            let kanaForms = MojiAnswerChecker.forms(of: kanji.reading ?? "")
            for (kanaForm, romajiForm) in zip(kanaForms, romajiForms) {
                #expect(MojiRomaji.spellings(of: kanaForm)?.contains(romajiForm) == true, "\(kanji.glyph) \(kanaForm)")
            }
        }
    }

    @Test func kunReadingTakesStemAndWord() throws {
        let see = try #require(catalog.character("j-見"))
        for typed in ["miru", "mi", "MIRU", "mi ru", "mi(ru)", "ken", "miseru"] {
            #expect(accepts(typed, see), "\(typed)")
        }
        for typed in ["mir", "miri", "m", "kan"] {
            #expect(!accepts(typed, see), "\(typed)")
        }
        let nine = try #require(catalog.character("j-九"))
        #expect(accepts("kyuu", nine))
        #expect(accepts("kyū", nine))
        #expect(!accepts("kyu", nine))
    }
}

@Suite("Typed character answers")
struct MojiCharacterAnswerTests {
    private let catalog = MojiAlphabetCatalog.shared

    private func kana(_ glyph: String) throws -> MojiCharacter {
        let pool = catalog.pool(.hiragana) + catalog.pool(.katakana)
        return try #require(pool.first { $0.glyph == glyph })
    }

    private func accepts(_ typed: String, _ character: MojiCharacter) -> Bool {
        MojiAnswerChecker.accepts(typed, for: character, direction: .romajiToGlyph)
    }

    @Test("Kana take the exact glyph and never the other script", arguments: [MojiScript.hiragana, .katakana])
    func kanaTakeTheExactGlyph(script: MojiScript) throws {
        for character in catalog.characters(script) {
            let glyph = character.glyph
            #expect(accepts(glyph, character), "\(glyph)")
            #expect(accepts(" \(glyph)\u{3000}\n", character), "\(glyph)")
            #expect(accepts(glyph.decomposedStringWithCanonicalMapping, character), "\(glyph)")
            #expect(!accepts(character.romaji, character), "\(glyph)")
            #expect(!accepts("", character))
            #expect(!accepts("\u{3000}", character))

            let otherScript = try #require(glyph.applyingTransform(.hiraganaToKatakana, reverse: script == .katakana))
            #expect(otherScript != glyph, "\(glyph)")
            #expect(!accepts(otherScript, character), "\(glyph) took \(otherScript)")
        }
    }

    @Test func kanaSlipsAreWrong() throws {
        let kya = try kana("きゃ")
        #expect(accepts("きゃ", kya))
        #expect(!accepts("きや", kya))
        #expect(!accepts("キャ", kya))
        #expect(!accepts("kya", kya))
        #expect(!accepts("きゃあ", kya))
        #expect(accepts("か\u{3099}", try kana("が")))
        #expect(accepts("ハ\u{309A}", try kana("パ")))
        #expect(!accepts("か", try kana("が")))
    }

    @Test("A kanji takes its glyph and never its reading in kana", arguments: MojiKanjiTheme.allCases)
    func kanjiTakeTheGlyph(theme: MojiKanjiTheme) {
        for kanji in catalog.pool(.kanji(theme)) {
            #expect(accepts(kanji.glyph, kanji), "\(kanji.glyph)")
            #expect(accepts(" \(kanji.glyph)\u{3000}", kanji), "\(kanji.glyph)")
            #expect(!accepts(kanji.romaji, kanji), "\(kanji.glyph)")
            for reading in [kanji.reading ?? ""] + kanji.otherReadings.map(\.kana) {
                for form in MojiAnswerChecker.forms(of: reading) where !form.isEmpty {
                    #expect(!accepts(form, kanji), "\(kanji.glyph) took \(form)")
                }
            }
        }
    }

    @Test func kanjiWithTheKanaEndingOfAReading() throws {
        let see = try #require(catalog.character("j-見"))
        for typed in ["見", "見る", "見せる", " 見る "] {
            #expect(accepts(typed, see), "\(typed)")
        }
        for typed in ["みる", "み", "見み", "見ru", "観る", "見るる"] {
            #expect(!accepts(typed, see), "\(typed)")
        }
        let new = try #require(catalog.character("j-新"))
        #expect(accepts("新しい", new))
        #expect(!accepts("新い", new))
        let day = try #require(catalog.character("j-日"))
        #expect(accepts("日", day))
        #expect(!accepts("日る", day))
    }
}

@Suite("Answer modes")
struct MojiAnswerModePlanningTests {
    private let catalog = MojiAlphabetCatalog.shared

    private var composer: MojiQuizComposer {
        MojiQuizComposer(catalog: catalog)
    }

    static let fixedModes: [MojiAnswerMode] = [
        MojiAnswerMode(input: .list, side: .romaji),
        MojiAnswerMode(input: .list, side: .character),
        MojiAnswerMode(input: .keyboard, side: .romaji),
        MojiAnswerMode(input: .keyboard, side: .character)
    ]

    @Test("The default is what Moji asked before modes")
    func standardMode() {
        #expect(MojiAnswerMode.standard == MojiAnswerMode(input: .list, side: .mixed))
    }

    @Test("A fixed mode asks exactly what it says", arguments: MojiPage.all, MojiAnswerModePlanningTests.fixedModes)
    func fixedModeIsObeyed(page: MojiPage, mode: MojiAnswerMode) throws {
        for character in catalog.pool(page) {
            var generator = SeededGenerator(state: 11)
            let question = try #require(composer.makeQuestion(for: character.id, mode: mode, using: &generator))

            let glyphFirst = catalog.requiresGlyphPrompt(character) || mode.side == .romaji
            let direction: MojiQuizDirection = glyphFirst ? .glyphToRomaji : .romajiToGlyph
            let typed = mode.input == .keyboard

            #expect(question.direction == direction)
            #expect(question.input == (typed ? .typing : .choice))
            #expect(question.optionIDs.count == (typed ? 0 : MojiQuizComposer.optionCount))
            #expect(composer.isPlayable(question))
        }
    }

    @Test("Everything random mixes both inputs and both sides", arguments: MojiPage.all)
    func everythingRandom(page: MojiPage) throws {
        let mode = MojiAnswerMode(input: .mixed, side: .mixed)
        var generator = SeededGenerator(state: 99)
        var kinds: Set<String> = []

        for character in catalog.pool(page) {
            let question = try #require(composer.makeQuestion(for: character.id, mode: mode, using: &generator))
            kinds.insert("\(question.input.rawValue) \(question.direction.rawValue)")
            #expect(composer.isPlayable(question))
        }
        #expect(kinds.count == 4)
    }

    @Test("The keyboard is never swapped for the list", arguments: MojiPage.all)
    func keyboardIsNeverForcedToTheList(page: MojiPage) throws {
        var generator = SeededGenerator(state: 21)
        for side in MojiAnswerSide.allCases {
            let mode = MojiAnswerMode(input: .keyboard, side: side)
            for character in catalog.pool(page) {
                let question = try #require(composer.makeQuestion(for: character.id, mode: mode, using: &generator))
                #expect(question.input == .typing, "\(character.glyph) \(side.rawValue)")
                #expect(question.optionIDs.isEmpty)
            }
        }
    }

    @Test("A kanji answered with the character can be typed", arguments: MojiKanjiTheme.allCases)
    func kanjiCharacterSideIsTyped(theme: MojiKanjiTheme) throws {
        let mode = MojiAnswerMode(input: .keyboard, side: .character)
        var generator = SeededGenerator(state: 3)
        var asked = 0
        for kanji in catalog.pool(.kanji(theme)) where !catalog.requiresGlyphPrompt(kanji) {
            let question = try #require(composer.makeQuestion(for: kanji.id, mode: mode, using: &generator))
            #expect(question.input == .typing, "\(kanji.glyph)")
            #expect(question.direction == .romajiToGlyph, "\(kanji.glyph)")
            #expect(composer.isPlayable(question))

            let session = MojiPracticeSession(
                id: UUID(),
                page: .kanji(theme),
                order: [kanji.id],
                answers: [],
                current: question,
                combo: 0,
                bestCombo: 0,
                startedAt: Date(),
                updatedAt: Date(),
                activeSeconds: 0
            )
            let model = try #require(PracticeQuestionModel.make(session: session, catalog: catalog))
            #expect(model.answerStyle == .character)
            #expect(model.options.isEmpty)
            #expect(model.prompt.title == kanji.meaning)
            #expect(model.accepts(kanji.glyph))
            asked += 1
        }
        #expect(asked == catalog.pool(.kanji(theme)).count)
        #expect(asked >= 60)
    }

    @Test("Each axis can be random on its own", arguments: [MojiPage.hiragana, .kanji(.people), .kanji(.oldForms)])
    func singleRandomAxis(page: MojiPage) throws {
        var generator = SeededGenerator(state: 5)
        var inputs: Set<MojiQuizInput> = []
        var directions: Set<MojiQuizDirection> = []
        for character in catalog.pool(page) where !catalog.requiresGlyphPrompt(character) {
            let byKeyboard = try #require(composer.makeQuestion(
                for: character.id,
                mode: MojiAnswerMode(input: .keyboard, side: .mixed),
                using: &generator
            ))
            directions.insert(byKeyboard.direction)

            let romajiSide = try #require(composer.makeQuestion(
                for: character.id,
                mode: MojiAnswerMode(input: .mixed, side: .romaji),
                using: &generator
            ))
            #expect(romajiSide.direction == .glyphToRomaji)
            inputs.insert(romajiSide.input)
        }
        #expect(directions == [.glyphToRomaji, .romajiToGlyph])
        #expect(inputs == [.choice, .typing])
    }

    @Test("A stored question the build can't ask is not playable")
    func unplayableQuestions() throws {
        let kanji = try #require(catalog.pool(.kanji(.people)).first)
        #expect(composer.isPlayable(MojiQuizQuestion(characterID: kanji.id, direction: .romajiToGlyph, optionIDs: [], input: .typing)))
        #expect(composer.isPlayable(MojiQuizQuestion(characterID: kanji.id, direction: .glyphToRomaji, optionIDs: [], input: .typing)))
        #expect(!composer.isPlayable(MojiQuizQuestion(characterID: "h-wo", direction: .romajiToGlyph, optionIDs: [], input: .typing)))
        #expect(!composer.isPlayable(MojiQuizQuestion(characterID: "h-a", direction: .glyphToRomaji, optionIDs: [], input: .choice)))
        #expect(!composer.isPlayable(MojiQuizQuestion(characterID: "h-nope", direction: .glyphToRomaji, optionIDs: [], input: .typing)))
    }

    @Test("The screen draws a question the way it was planned")
    func questionModelFollowsThePlan() throws {
        func model(_ id: String, _ direction: MojiQuizDirection, _ input: MojiQuizInput, _ page: MojiPage) -> PracticeQuestionModel? {
            let session = MojiPracticeSession(
                id: UUID(),
                page: page,
                order: [id],
                answers: [],
                current: MojiQuizQuestion(characterID: id, direction: direction, optionIDs: [], input: input),
                combo: 0,
                bestCombo: 0,
                startedAt: Date(),
                updatedAt: Date(),
                activeSeconds: 0
            )
            return PracticeQuestionModel.make(session: session, catalog: catalog)
        }

        let romaji = try #require(model("h-shi", .glyphToRomaji, .typing, .hiragana))
        #expect(romaji.answerStyle == .romaji)
        #expect(romaji.options.isEmpty)
        #expect(romaji.accepts("si"))

        let katakana = try #require(model("k-kya", .romajiToGlyph, .typing, .katakana))
        #expect(katakana.answerStyle == .character)
        #expect(katakana.isTyped)
        #expect(katakana.accepts("キャ"))
        #expect(!katakana.accepts("きゃ"))

        let see = try #require(catalog.character("j-見"))
        let reading = try #require(model(see.id, .glyphToRomaji, .typing, see.page))
        #expect(reading.answerStyle == .romaji)
        #expect(reading.page == see.page)
        #expect(reading.prompt.subtitle == see.meaning)
        #expect(reading.answerLines.count == 2)

        let written = try #require(model(see.id, .romajiToGlyph, .typing, see.page))
        #expect(written.answerStyle == .character)
        #expect(written.options.isEmpty)
        #expect(written.prompt.title == see.meaning)
        #expect(written.prompt.subtitle == see.readingLine)
        #expect(written.accepts("見"))
        #expect(written.accepts("見る"))
        #expect(!written.accepts("みる"))
        #expect(!written.accepts("miru"))
    }
}

@Suite("Answer modes on disk")
struct MojiAnswerModePersistenceTests {
    private let catalog = MojiAlphabetCatalog.shared

    private func makeRepository(at directory: URL) -> MojiPracticeRepository {
        MojiPracticeRepository(
            resources: MojiPracticeResourceRepository(store: MojiDiskStore(directory: directory)),
            catalog: catalog
        )
    }

    private func scratchDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("moji-modes-\(UUID().uuidString)", isDirectory: true)
    }

    private func submission(
        _ session: MojiPracticeSession,
        index: Int,
        chosenID: String? = nil,
        typed: String? = nil
    ) -> MojiAnswerSubmission {
        MojiAnswerSubmission(
            page: session.page,
            sessionID: session.id,
            questionIndex: index,
            chosenID: chosenID,
            thinkSeconds: 1,
            answeredAt: Date(),
            typed: typed
        )
    }

    @Test("Modes are saved per page and survive a restart and a progress reset")
    func modesPersist() async {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = makeRepository(at: directory)
        await repository.setAnswerMode(MojiAnswerMode(input: .mixed, side: .mixed), for: [.kanji(.people)])
        await repository.setAnswerInput(.keyboard, for: .hiragana)
        await repository.setAnswerSide(.character, for: .hiragana)

        var snapshot = await makeRepository(at: directory).activate()
        #expect(snapshot.answerMode(for: .kanji(.people)) == MojiAnswerMode(input: .mixed, side: .mixed))
        #expect(snapshot.answerMode(for: .kanji(.time)) == .standard)
        #expect(snapshot.answerMode(for: .hiragana) == MojiAnswerMode(input: .keyboard, side: .character))
        #expect(snapshot.answerMode(for: .katakana) == .standard)

        let themes = MojiKanjiTheme.allCases.map { MojiPage.kanji($0) }
        await repository.copyAnswerMode(from: .kanji(.people), to: themes)
        snapshot = await makeRepository(at: directory).activate()
        for page in themes {
            #expect(snapshot.answerMode(for: page) == MojiAnswerMode(input: .mixed, side: .mixed), "\(page.rawValue)")
        }
        #expect(snapshot.answerMode(for: .katakana) == .standard)

        await repository.copyAnswerMode(from: .hiragana, to: MojiPage.all)
        await repository.resetAll()
        snapshot = await makeRepository(at: directory).activate()
        for page in MojiPage.all {
            #expect(snapshot.answerMode(for: page) == MojiAnswerMode(input: .keyboard, side: .character), "\(page.rawValue)")
        }
    }

    @Test("A resumed session keeps its planned question; the next one follows the new mode")
    func modeChangeAppliesFromTheNextQuestion() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = makeRepository(at: directory)
        let session = try #require(await repository.startSession(page: .katakana, now: Date()))
        let planned = try #require(session.current)
        #expect(planned.input == .choice)

        await repository.setAnswerMode(MojiAnswerMode(input: .keyboard, side: .romaji), for: [.katakana])
        let resumed = try #require(await repository.startSession(page: .katakana, now: Date()))
        #expect(resumed.id == session.id)
        #expect(resumed.current == planned)

        let reloaded = makeRepository(at: directory)
        #expect(await reloaded.activate().sessions[.katakana]?.current == planned)

        let outcome = await reloaded.answer(submission(session, index: 0, chosenID: planned.characterID))
        guard case .next(let next)? = outcome else {
            Issue.record("expected a next question")
            return
        }
        let question = try #require(next.current)
        #expect(question.input == .typing)
        #expect(question.direction == .glyphToRomaji)
        #expect(question.optionIDs.isEmpty)
        #expect(await makeRepository(at: directory).activate().sessions[.katakana]?.current == question)
    }

    @Test("Typed answers are checked by the repository and kept with the answer")
    func typedAnswersAreChecked() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = makeRepository(at: directory)
        await repository.setAnswerMode(MojiAnswerMode(input: .keyboard, side: .romaji), for: [.hiragana])
        let session = try #require(await repository.startSession(page: .hiragana, now: Date()))

        let first = try #require(session.current)
        let firstCharacter = try #require(catalog.character(first.characterID))
        #expect(first.input == .typing)
        guard case .next(let afterFirst)? = await repository.answer(
            submission(session, index: 0, typed: " \(firstCharacter.romaji.uppercased()) ")
        ) else {
            Issue.record("expected a next question")
            return
        }
        #expect(afterFirst.answers.last?.isCorrect == true)
        #expect(afterFirst.answers.last?.chosenID == nil)
        #expect(afterFirst.answers.last?.typed == " \(firstCharacter.romaji.uppercased()) ")

        let second = try #require(afterFirst.current)
        guard case .next(let afterSecond)? = await repository.answer(
            submission(session, index: 1, typed: "qqq")
        ) else {
            Issue.record("expected a next question")
            return
        }
        #expect(afterSecond.answers.last?.isCorrect == false)
        #expect(afterSecond.combo == 0)

        let snapshot = await repository.activate()
        #expect(snapshot.progress[firstCharacter.id]?.correct == 1)
        #expect(snapshot.progress[second.characterID]?.seen == 1)
        #expect(snapshot.progress[second.characterID]?.correct == 0)
    }

    @Test("Kana typed as the character must be exactly the character")
    func typedCharactersAreExact() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = makeRepository(at: directory)
        await repository.setAnswerMode(MojiAnswerMode(input: .keyboard, side: .character), for: [.katakana])
        var session = try #require(await repository.startSession(page: .katakana, now: Date()))
        var index = 0
        while let current = session.current, current.direction != .romajiToGlyph {
            guard case .next(let next)? = await repository.answer(
                submission(session, index: index, chosenID: current.characterID)
            ) else {
                Issue.record("expected a next question")
                return
            }
            session = next
            index += 1
        }

        let question = try #require(session.current)
        let character = try #require(catalog.character(question.characterID))
        #expect(question.input == .typing)
        guard case .next(let answered)? = await repository.answer(
            submission(session, index: index, typed: character.glyph)
        ) else {
            Issue.record("expected a next question")
            return
        }
        #expect(answered.answers.last?.isCorrect == true)
    }

    @Test("A session saved before answer modes resumes as multiple choice")
    func legacySessionResumes() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let legacy = """
        {"savedAt":0,"value":[{"activeSeconds":3,"answers":[{"answeredAt":0,"characterID":"h-a",\
        "chosenID":"h-a","isCorrect":true}],"bestCombo":1,"combo":1,"current":{"characterID":"h-i",\
        "direction":"romaji_to_glyph","optionIDs":["h-i","h-ri","h-ko","h-a"]},\
        "id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","order":["h-a","h-i","h-u"],"script":"hiragana",\
        "startedAt":0,"updatedAt":0}],"version":1}
        """
        try Data(legacy.utf8).write(to: directory.appendingPathComponent("practice.sessions.json"))

        let snapshot = await makeRepository(at: directory).activate()
        let session = try #require(snapshot.sessions[.hiragana])
        #expect(session.answeredCount == 1)
        #expect(session.answers.first?.typed == nil)
        #expect(session.current == MojiQuizQuestion(
            characterID: "h-i",
            direction: .romajiToGlyph,
            optionIDs: ["h-i", "h-ri", "h-ko", "h-a"],
            input: .choice
        ))
    }

    @Test("A mode written by a newer build falls back per axis")
    func unknownModeValues() throws {
        let mode = try JSONDecoder().decode(
            MojiAnswerMode.self,
            from: Data(#"{"input":"voice","side":"character"}"#.utf8)
        )
        #expect(mode == MojiAnswerMode(input: .list, side: .character))
    }
}
