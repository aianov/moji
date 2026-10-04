import Foundation
import Testing
@testable import Moji

@Suite("My cards: write, edit, delete")
struct MojiOwnCardsTests {
    private typealias Support = MojiWordTestSupport

    static func mine(at directory: URL, store: MojiDiskStore? = nil) -> MojiWordRepository {
        MojiWordRepository(
            resources: MojiWordResourceRepository(store: store ?? MojiDiskStore(directory: directory), deck: .mine),
            calendar: Support.calendar,
            learningFuzz: { 0 }
        )
    }

    static func input(
        _ written: String,
        _ meaning: String,
        sentence: String = "",
        translation: String = "",
        note: String = ""
    ) -> MojiOwnWordInput {
        MojiOwnWordInput(
            written: written,
            reading: MojiWordReadings.reading(of: written),
            meaning: meaning,
            sentence: MojiWordReadings.markingTarget(MojiWordReadings.tokens(of: sentence), word: written),
            translation: translation,
            note: note
        )
    }

    @Test("The word and its meaning are required, and the word has to be Japanese")
    func validation() {
        #expect(MojiOwnWordInput(written: "食べる", meaning: "eat").problems.isEmpty)
        #expect(MojiOwnWordInput(written: "  ", meaning: "eat").problems == [.missingWord])
        #expect(MojiOwnWordInput(written: "eat", meaning: "есть").problems == [.wordNotJapanese])
        #expect(MojiOwnWordInput(written: "食べる", meaning: " \n ").problems == [.missingMeaning])
        #expect(MojiOwnWordInput().problems == [.missingWord, .missingMeaning])
        #expect(MojiOwnWordInput(written: "Tシャツ", meaning: "T-shirt").isValid)
        #expect(MojiOwnWordInput(written: "ねこ", meaning: "cat", sentence: [], translation: "", note: "").isValid)
    }

    @Test("Saving trims every field, fills a kana reading and turns a typed reading into hiragana")
    func cleaning() {
        let raw = MojiOwnWordInput(
            written: " 食べる\n",
            reading: "taberu",
            meaning: "  eat ",
            sentence: MojiWordReadings.tokens(of: " パンを食べる "),
            translation: " I eat bread. ",
            note: "\n ichidan verb \n"
        )
        let clean = raw.cleaned()
        #expect(clean.written == "食べる")
        #expect(clean.reading == "たべる")
        #expect(clean.meaning == "eat")
        #expect(clean.sentence.map(\.surface).joined() == "パンを食べる")
        #expect(clean.sentence.allSatisfy { $0.hasKanji || $0.reading == nil })
        #expect(clean.translation == "I eat bread.")
        #expect(clean.note == "ichidan verb")
        #expect(MojiOwnWordInput(written: "コーヒー", meaning: "coffee").cleaned().reading == "こーひー")
        #expect(MojiOwnWordInput(written: "猫", meaning: "cat", sentence: MojiWordReadings.tokens(of: "   ")).cleaned().sentence.isEmpty)
    }

    @Test("Write, edit and delete cards; they keep the order they were added in")
    func writeEditDelete() async throws {
        let directory = Support.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = Self.mine(at: directory)
        let start = await repository.activate()
        #expect(start.isLoaded)
        #expect(start.catalog.isEmpty)

        let first = try #require(await repository.addOwnWord(
            Self.input("食べる", "eat", sentence: "毎朝パンを食べます", translation: "I eat bread every morning."),
            now: Support.now
        ))
        let second = try #require(await repository.addOwnWord(Self.input("猫", "кошка"), now: Support.now.addingTimeInterval(60)))
        #expect(MojiOwnWord.isOwnID(first.id))
        #expect(MojiWordDeck.of(wordID: first.id) == .mine)
        #expect(first.id != second.id)
        #expect(await repository.addOwnWord(MojiOwnWordInput(written: "cat", meaning: "кошка"), now: Support.now) == nil)
        #expect(await repository.addOwnWord(MojiOwnWordInput(written: "犬", meaning: ""), now: Support.now) == nil)

        var snapshot = await repository.currentSnapshot(now: Support.now)
        #expect(snapshot.catalog.words.map(\.id) == [first.id, second.id])
        #expect(snapshot.catalog.sections.count == 1)
        #expect(snapshot.queue.new == 2)
        let eat = try #require(snapshot.catalog.word(first.id))
        #expect(eat.reading == "たべる")
        #expect(eat.romaji == "taberu")
        #expect(eat.meaning(in: .ru) == "eat")
        #expect(eat.meaning(in: .en) == "eat")
        let sentence = try #require(eat.sentence(at: 0))
        #expect(sentence.text == "毎朝パンを食べます")
        #expect(sentence.translation(in: .ru) == "I eat bread every morning.")
        #expect(sentence.tokens.filter(\.isTarget).map(\.surface) == ["食べ"])
        #expect(snapshot.catalog.word(second.id)?.sentences.isEmpty == true)
        #expect(snapshot.catalog.search.matches("кошка") == [second.id])
        #expect(snapshot.catalog.search.matches("taberu") == [first.id])

        let step = await repository.startSession(.deck, now: Support.now)
        guard case .card(let studied) = step else {
            Issue.record("Expected a card from my deck")
            return
        }
        #expect(studied.id.wordID == first.id)
        _ = await repository.answer(studied.id, button: .easy, seconds: 3, now: Support.now)
        _ = await repository.endSession(now: Support.now)
        let progressed = await repository.currentSnapshot(now: Support.now).card(studied.id)
        #expect(progressed.phase == .review)

        var change = first.input
        change.meaning = "to eat"
        change.note = "ichidan"
        let edited = try #require(await repository.updateOwnWord(first.id, with: change, now: Support.now.addingTimeInterval(120)))
        #expect(edited.meaning == "to eat")
        #expect(edited.createdAt == first.createdAt)
        #expect(edited.updatedAt > first.updatedAt)
        snapshot = await repository.currentSnapshot(now: Support.now)
        #expect(snapshot.catalog.word(first.id)?.english == "to eat")
        #expect(snapshot.catalog.words.map(\.id) == [first.id, second.id])
        #expect(snapshot.notes[first.id] == "ichidan")
        #expect(snapshot.card(studied.id) == progressed)
        #expect(await repository.updateOwnWord(first.id, with: MojiOwnWordInput(written: "", meaning: "x"), now: Support.now) == nil)
        #expect(await repository.updateOwnWord("my-missing", with: change, now: Support.now) == nil)

        await repository.setNote("  from the card details  ", wordID: first.id, now: Support.now)
        #expect(await repository.ownWord(first.id)?.note == "from the card details")
        #expect(await repository.currentSnapshot(now: Support.now).notes[first.id] == "from the card details")

        #expect(await repository.deleteOwnWords([first.id, "my-missing"], now: Support.now) == 1)
        snapshot = await repository.currentSnapshot(now: Support.now)
        #expect(snapshot.catalog.words.map(\.id) == [second.id])
        #expect(snapshot.cards[studied.id.key] == nil)
        #expect(snapshot.notes[first.id] == nil)
        #expect(await repository.history(wordID: first.id).isEmpty)
        #expect(await repository.deleteOwnWords([first.id], now: Support.now) == 0)

        let reopened = await Self.mine(at: directory).activate()
        #expect(reopened.catalog.words.map(\.id) == [second.id])
        #expect(reopened.cards[studied.id.key] == nil)
    }

    @Test("The frequent deck takes no cards of its own")
    func frequentDeckRefusesCards() async {
        let directory = Support.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let frequent = Support.repository(at: directory, catalog: Support.catalog(count: 2))
        #expect(frequent.deck == .frequent)
        #expect(await frequent.addOwnWord(Self.input("猫", "cat"), now: Support.now) == nil)
        #expect(await frequent.deleteOwnWords(["t1"], now: Support.now) == 0)
        #expect(await frequent.currentSnapshot(now: Support.now).catalog.words.count == 2)
    }

    @Test("A note written in the form shows on the card and in the notes of the deck")
    func noteFromTheForm() async throws {
        let directory = Support.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = Self.mine(at: directory)
        let word = try #require(await repository.addOwnWord(Self.input("鳥", "bird", note: "とり, not しま"), now: Support.now))
        let snapshot = await repository.currentSnapshot(now: Support.now)
        #expect(snapshot.notes == [word.id: "とり, not しま"])
        #expect(MojiWordDeck.of(wordID: "w1483070") == .frequent)
    }
}
