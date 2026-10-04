import Foundation
import Testing
@testable import Moji

@Suite("Drawing answers")
struct MojiDrawingAnswerTests {
    private let catalog = MojiAlphabetCatalog.shared

    private static let drawing = MojiAnswerMode(input: .drawing, side: .romaji)

    private func composer() throws -> MojiQuizComposer {
        let library = try #require(WritingFixture.library)
        return MojiQuizComposer(catalog: catalog, strokes: library)
    }

    @Test("Drawing asks every character with strokes from its romaji or meaning", arguments: MojiPage.all)
    func drawingIsAsked(page: MojiPage) throws {
        let library = try #require(WritingFixture.library)
        let composer = try composer()
        var generator = SeededGenerator(state: 41)
        var drawn = 0
        for character in catalog.pool(page) {
            let question = try #require(composer.makeQuestion(for: character.id, mode: Self.drawing, using: &generator))
            #expect(composer.isPlayable(question), "\(character.glyph)")
            if library.canWrite(character.glyph), !catalog.requiresGlyphPrompt(character) {
                #expect(question.input == .drawing, "\(character.glyph)")
                #expect(question.direction == .romajiToGlyph, "\(character.glyph)")
                #expect(question.optionIDs.isEmpty)
                drawn += 1
            } else {
                #expect(question.input == .choice, "\(character.glyph)")
                #expect(question.optionIDs.count == MojiQuizComposer.optionCount)
                #expect(question.optionIDs.contains(character.id))
            }
        }
        #expect(drawn > 0)
    }

    @Test("Characters without strokes, and kana spelled like another kana, fall back to the list")
    func fallbacks() throws {
        let composer = try composer()
        let strokeless = catalog.characters(.kanji).filter { WritingFixture.missingOldForms.contains($0.glyph) }
        #expect(strokeless.count == WritingFixture.missingOldForms.count)
        for kanji in strokeless {
            var generator = SeededGenerator(state: 5)
            let question = try #require(composer.makeQuestion(for: kanji.id, mode: Self.drawing, using: &generator))
            #expect(question.input == .choice, "\(kanji.glyph)")
            #expect(question.direction == .romajiToGlyph, "\(kanji.glyph)")
            #expect(question.optionIDs.contains(kanji.id))
            #expect(composer.isPlayable(question))
            #expect(!composer.isPlayable(MojiQuizQuestion(characterID: kanji.id, direction: .romajiToGlyph, optionIDs: [], input: .drawing)))
        }

        for id in ["h-wo", "h-di", "h-du", "k-di", "k-du"] {
            var generator = SeededGenerator(state: 9)
            let question = try #require(composer.makeQuestion(for: id, mode: Self.drawing, using: &generator))
            #expect(question.input == .choice, "\(id)")
            #expect(question.direction == .glyphToRomaji, "\(id)")
            #expect(!composer.isPlayable(MojiQuizQuestion(characterID: id, direction: .romajiToGlyph, optionIDs: [], input: .drawing)))
        }

        let blind = MojiQuizComposer(catalog: catalog, strokes: nil)
        var generator = SeededGenerator(state: 13)
        for character in catalog.pool(.hiragana) {
            let question = try #require(blind.makeQuestion(for: character.id, mode: Self.drawing, using: &generator))
            #expect(question.input == .choice, "\(character.glyph)")
        }
        let ka = MojiQuizQuestion(characterID: "h-ka", direction: .romajiToGlyph, optionIDs: [], input: .drawing)
        #expect(composer.isPlayable(ka))
        #expect(!blind.isPlayable(ka))
        #expect(!composer.isPlayable(MojiQuizQuestion(characterID: "h-ka", direction: .glyphToRomaji, optionIDs: [], input: .drawing)))
    }

    @Test("Mixed keeps to the list and the keyboard", arguments: MojiPage.all)
    func mixedNeverDraws(page: MojiPage) throws {
        let composer = try composer()
        var generator = SeededGenerator(state: 77)
        for side in MojiAnswerSide.allCases {
            let mode = MojiAnswerMode(input: .mixed, side: side)
            for character in catalog.pool(page) {
                let question = try #require(composer.makeQuestion(for: character.id, mode: mode, using: &generator))
                #expect(question.input != .drawing, "\(character.glyph)")
            }
        }
    }

    @Test("Answer modes decode, old and new")
    func modesDecode() throws {
        let decoder = JSONDecoder()
        let stored: [(String, MojiAnswerMode)] = [
            (#"{"input":"list","side":"romaji"}"#, MojiAnswerMode(input: .list, side: .romaji)),
            (#"{"input":"keyboard","side":"character"}"#, MojiAnswerMode(input: .keyboard, side: .character)),
            (#"{"input":"mixed","side":"mixed"}"#, MojiAnswerMode(input: .mixed, side: .mixed)),
            (#"{"input":"drawing","side":"romaji"}"#, MojiAnswerMode(input: .drawing, side: .romaji)),
            (#"{"input":"drawing"}"#, MojiAnswerMode(input: .drawing, side: .mixed)),
            (#"{"input":"tracing","side":"character"}"#, MojiAnswerMode(input: .list, side: .character))
        ]
        for (json, expected) in stored {
            #expect(try decoder.decode(MojiAnswerMode.self, from: Data(json.utf8)) == expected, "\(json)")
        }

        let mode = MojiAnswerMode(input: .drawing, side: .romaji)
        #expect(try decoder.decode(MojiAnswerMode.self, from: JSONEncoder().encode(mode)) == mode)
        #expect(mode.askedSide == .character)
        #expect(MojiAnswerMode(input: .keyboard, side: .romaji).askedSide == .romaji)
        #expect(MojiAnswerInput.allCases == [.list, .keyboard, .mixed, .drawing])
    }

    @Test("A drawing is right when finished with at most one mistake, hint taps included", arguments: [
        (0, 0, true, true), (1, 0, true, true), (0, 1, true, true),
        (1, 1, true, false), (2, 0, true, false), (0, 2, true, false), (3, 2, true, false),
        (0, 0, false, false), (1, 0, false, false)
    ])
    func grading(failures: Int, hints: Int, isFinished: Bool, isCorrect: Bool) {
        let drawn = MojiDrawnAnswer(failures: failures, hints: hints, isFinished: isFinished)
        #expect(drawn.mistakes == failures + hints)
        #expect(drawn.isCorrect == isCorrect)
        #expect(drawn.isSettled == (isCorrect || failures + hints >= 2))
        #expect(drawn.isCorrect == (isFinished && MojiDrawingHint(mistakes: failures + hints) < .whole))
    }

    @Test("A drawing question takes nothing but a drawing")
    func onlyADrawingCounts() throws {
        let ka = try #require(catalog.character("h-ka"))
        let question = MojiQuizQuestion(characterID: ka.id, direction: .romajiToGlyph, optionIDs: [], input: .drawing)
        func check(chosenID: String? = nil, typed: String? = nil, drawn: MojiDrawnAnswer? = nil) -> Bool {
            MojiAnswerChecker.isCorrect(chosenID: chosenID, typed: typed, drawn: drawn, question: question, answer: ka)
        }
        #expect(check(drawn: MojiDrawnAnswer(failures: 0, hints: 1, isFinished: true)))
        #expect(!check(drawn: MojiDrawnAnswer(failures: 1, hints: 1, isFinished: true)))
        #expect(!check(drawn: MojiDrawnAnswer(failures: 0, hints: 0, isFinished: false)))
        #expect(!check(chosenID: ka.id))
        #expect(!check(typed: ka.glyph))
        #expect(!check())

        let clean = MojiDrawnAnswer(failures: 0, hints: 0, isFinished: true)
        #expect(!MojiAnswerChecker.isCorrect(chosenID: nil, typed: nil, drawn: clean, question: question, answer: catalog.character("h-ki")))
        let choice = MojiQuizQuestion(characterID: ka.id, direction: .romajiToGlyph, optionIDs: [ka.id], input: .choice)
        #expect(!MojiAnswerChecker.isCorrect(chosenID: nil, typed: nil, drawn: clean, question: choice, answer: ka))
    }

    @Test("The screen shows the romaji or the meaning over the character's strokes")
    func questionModel() throws {
        let library = try #require(WritingFixture.library)
        func model(_ id: String, strokes: MojiStrokeLibrary?) throws -> PracticeQuestionModel? {
            let character = try #require(catalog.character(id))
            let session = MojiPracticeSession(
                id: UUID(),
                page: character.page,
                order: [id],
                answers: [],
                current: MojiQuizQuestion(characterID: id, direction: .romajiToGlyph, optionIDs: [], input: .drawing),
                combo: 0,
                bestCombo: 0,
                startedAt: Date(),
                updatedAt: Date(),
                activeSeconds: 0
            )
            return PracticeQuestionModel.make(session: session, catalog: catalog, strokes: strokes)
        }

        let kya = try #require(try model("h-kya", strokes: library))
        #expect(kya.answerStyle == .drawing)
        #expect(kya.isDrawn)
        #expect(!kya.isTyped)
        #expect(kya.options.isEmpty)
        #expect(kya.prompt.title == "kya")
        #expect(!kya.prompt.isGlyph)
        #expect(kya.figure?.cellCount == 2)
        #expect(kya.figure?.strokeCount == 7)
        #expect(kya.instruction == String(localized: "Draw this sound in hiragana"))

        let tree = try #require(catalog.character("j-木"))
        let kanji = try #require(try model(tree.id, strokes: library))
        #expect(kanji.prompt.title == tree.meaning)
        #expect(kanji.prompt.subtitle == tree.readingLine)
        #expect(kanji.prompt.isMeaning)
        #expect(kanji.figure?.cellCount == 1)
        #expect(kanji.answerLines.count == 2)
        #expect(kanji.instruction == String(localized: "Draw the kanji that means this"))

        #expect(try model("h-kya", strokes: nil) == nil)
    }
}

@Suite("Drawing answers on disk")
struct MojiDrawingRepositoryTests {
    private let catalog = MojiAlphabetCatalog.shared

    private func makeRepository(at directory: URL, strokes: MojiStrokeLibrary? = WritingFixture.library) -> MojiPracticeRepository {
        MojiPracticeRepository(
            resources: MojiPracticeResourceRepository(store: MojiDiskStore(directory: directory)),
            catalog: catalog,
            strokes: strokes
        )
    }

    private func scratchDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("moji-drawing-\(UUID().uuidString)", isDirectory: true)
    }

    private func submission(
        _ session: MojiPracticeSession,
        index: Int,
        chosenID: String? = nil,
        drawn: MojiDrawnAnswer? = nil
    ) -> MojiAnswerSubmission {
        MojiAnswerSubmission(
            page: session.page,
            sessionID: session.id,
            questionIndex: index,
            chosenID: chosenID,
            thinkSeconds: 1,
            answeredAt: Date(),
            drawn: drawn
        )
    }

    @Test("Drawing is saved per page and spreads to every page like the other modes")
    func modeIsSaved() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = makeRepository(at: directory)
        await repository.setAnswerInput(.drawing, for: .hiragana)
        var snapshot = await makeRepository(at: directory).activate()
        #expect(snapshot.answerMode(for: .hiragana) == MojiAnswerMode(input: .drawing, side: .mixed))
        #expect(snapshot.answerMode(for: .katakana) == .standard)

        await repository.copyAnswerMode(from: .hiragana, to: catalog.pages(.kanji))
        snapshot = await makeRepository(at: directory).activate()
        for page in catalog.pages(.kanji) {
            #expect(snapshot.answerMode(for: page) == MojiAnswerMode(input: .drawing, side: .mixed), "\(page.rawValue)")
        }
        #expect(snapshot.answerMode(for: .katakana) == .standard)

        await repository.copyAnswerMode(from: .hiragana, to: MojiPage.all)
        snapshot = await makeRepository(at: directory).activate()
        for page in MojiPage.all {
            #expect(snapshot.answerMode(for: page).input == .drawing, "\(page.rawValue)")
        }
    }

    @Test("A drawn answer runs through the session: graded, kept with the answer, in mastery and the summary")
    func drawnAnswersFlow() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = makeRepository(at: directory)
        await repository.setAnswerMode(MojiAnswerMode(input: .drawing, side: .romaji), for: [.katakana])
        let session = try #require(await repository.startSession(page: .katakana, now: Date()))

        let plan: [MojiDrawnAnswer?] = [
            MojiDrawnAnswer(failures: 0, hints: 0, isFinished: true),
            MojiDrawnAnswer(failures: 0, hints: 1, isFinished: true),
            MojiDrawnAnswer(failures: 1, hints: 1, isFinished: false),
            nil
        ]
        var current = session
        var index = 0
        var drawnIDs: [String] = []
        var listIDs: [String] = []
        var checkedSaved = false
        var completion: MojiPracticeCompletion?

        while completion == nil {
            let question = try #require(current.current)
            let answer: MojiAnswerSubmission
            switch question.input {
            case .drawing:
                let drawn = drawnIDs.count < plan.count ? plan[drawnIDs.count] : MojiDrawnAnswer(failures: 1, hints: 0, isFinished: true)
                answer = submission(session, index: index, drawn: drawn)
                drawnIDs.append(question.characterID)
            case .choice:
                answer = submission(session, index: index, chosenID: question.characterID)
                listIDs.append(question.characterID)
            case .typing:
                Issue.record("drawing asked a typed question")
                return
            }

            switch try #require(await repository.answer(answer)) {
            case .next(let next):
                current = next
            case .completed(let done):
                completion = done
            }
            index += 1

            if drawnIDs.count == plan.count, !checkedSaved {
                checkedSaved = true
                let saved = try #require(await makeRepository(at: directory).activate().sessions[.katakana])
                let drawnAnswers = saved.answers.filter { drawnIDs.contains($0.characterID) }
                #expect(drawnAnswers.map(\.drawn) == plan)
                #expect(drawnAnswers.map(\.isCorrect) == [true, true, false, false])
                #expect(drawnAnswers.allSatisfy { $0.chosenID == nil && $0.typed == nil })
                #expect(saved.current == current.current)
            }
        }

        let done = try #require(completion)
        #expect(Set(listIDs) == ["k-di", "k-du"])
        #expect(drawnIDs.count == catalog.pool(.katakana).count - 2)
        #expect(done.record.total == catalog.pool(.katakana).count)
        #expect(done.record.correct == done.record.total - 2)
        #expect(Set(done.record.mistakeIDs) == Set(drawnIDs[2...3]))
        #expect(done.page == .katakana)

        let snapshot = await makeRepository(at: directory).activate()
        #expect(snapshot.sessions[.katakana] == nil)
        #expect(snapshot.activity.pagesDoneToday == [.katakana])
        #expect(snapshot.progress[drawnIDs[0]]?.strength == 1)
        #expect(snapshot.progress[drawnIDs[1]]?.strength == 1)
        #expect(snapshot.progress[drawnIDs[2]]?.strength == 0)
        #expect(snapshot.progress[drawnIDs[2]]?.seen == 1)
        #expect(snapshot.progress[drawnIDs[3]]?.correct == 0)
        #expect(snapshot.progress.values.allSatisfy { !$0.isWritten })
    }

    @Test("A saved drawing question resumes as a drawing, or as a list without stroke data")
    func savedDrawingResumes() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let saved = """
        {"savedAt":0,"value":[{"activeSeconds":3,"answers":[{"answeredAt":0,"characterID":"h-a",\
        "chosenID":null,"drawn":{"failures":1,"hints":0,"isFinished":true},"isCorrect":true}],\
        "bestCombo":1,"combo":1,"current":{"characterID":"h-ka","direction":"romaji_to_glyph",\
        "input":"drawing","optionIDs":[]},"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF",\
        "order":["h-a","h-ka","h-u"],"page":"hiragana","startedAt":0,"updatedAt":0}],"version":1}
        """
        try Data(saved.utf8).write(to: directory.appendingPathComponent("practice.sessions.json"))

        let session = try #require(await makeRepository(at: directory).activate().sessions[.hiragana])
        #expect(session.answeredCount == 1)
        #expect(session.answers.first?.drawn == MojiDrawnAnswer(failures: 1, hints: 0, isFinished: true))
        #expect(session.current == MojiQuizQuestion(characterID: "h-ka", direction: .romajiToGlyph, optionIDs: [], input: .drawing))

        let blind = try #require(await makeRepository(at: directory, strokes: nil).activate().sessions[.hiragana]?.current)
        #expect(blind.characterID == "h-ka")
        #expect(blind.input == .choice)
        #expect(blind.optionIDs.contains("h-ka"))
    }
}
