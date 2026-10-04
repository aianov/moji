import Foundation
import Testing
@testable import Moji

@Suite("My cards beside the frequent deck")
struct MojiOwnDeckTests {
    private typealias Support = MojiWordTestSupport

    private struct Decks {
        let store: MojiDiskStore
        let frequent: MojiWordRepository
        let mine: MojiWordRepository
    }

    private func decks(at directory: URL) -> Decks {
        let store = MojiDiskStore(directory: directory)
        return Decks(
            store: store,
            frequent: MojiWordRepository(
                resources: MojiWordResourceRepository(store: store),
                catalogLoader: { Support.catalog(count: 5) },
                calendar: Support.calendar,
                learningFuzz: { 0 }
            ),
            mine: MojiWordRepository(
                resources: MojiWordResourceRepository(store: store, deck: .mine),
                calendar: Support.calendar,
                learningFuzz: { 0 }
            )
        )
    }

    private func card(_ step: MojiWordStudyStep?) -> MojiWordStudyCard? {
        guard case .card(let card) = step else { return nil }
        return card
    }

    private func summary(_ step: MojiWordStudyStep?) -> MojiWordSessionSummary? {
        guard case .finished(let summary) = step else { return nil }
        return summary
    }

    private func addCards(_ count: Int, to repository: MojiWordRepository) async -> [MojiOwnWord] {
        let samples = [("猫", "cat"), ("犬", "dog"), ("鳥", "bird"), ("魚", "fish"), ("馬", "horse")]
        var words: [MojiOwnWord] = []
        for index in 0..<count {
            let sample = samples[index % samples.count]
            let input = MojiOwnWordInput(
                written: sample.0,
                reading: MojiWordReadings.reading(of: sample.0),
                meaning: "\(sample.1) \(index + 1)"
            )
            if let word = await repository.addOwnWord(input, now: Support.now.addingTimeInterval(Double(index))) {
                words.append(word)
            }
        }
        return words
    }

    private func study(
        _ repository: MojiWordRepository,
        from start: Date,
        firstAnswer: ((MojiWordStudyCard) async -> Void)? = nil
    ) async -> (wordIDs: [String], summary: MojiWordSessionSummary?, end: Date) {
        var now = start
        var seen: [String] = []
        var step: MojiWordStudyStep? = await repository.startSession(.deck, now: now)
        if let current = card(step) {
            await firstAnswer?(current)
        }
        while let current = card(step), seen.count < 60 {
            seen.append(current.id.wordID)
            now = now.addingTimeInterval(5)
            step = await repository.answer(current.id, button: .good, seconds: 2, now: now)
        }
        return (seen, summary(step), now)
    }

    @Test("A session of one deck never shows a card of the other")
    func sessionsStayInTheirDeck() async throws {
        let directory = Support.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let decks = decks(at: directory)
        _ = await decks.frequent.activate()
        let own = await addCards(3, to: decks.mine)
        #expect(own.count == 3)

        let mine = await study(decks.mine, from: Support.now)
        #expect(!mine.wordIDs.isEmpty)
        #expect(Set(mine.wordIDs) == Set(own.map(\.id)))
        #expect(mine.summary?.deck == .mine)
        #expect(mine.summary?.isComplete == true)

        let frequent = await study(decks.frequent, from: mine.end) { _ in
            let foreign = await decks.frequent.answer(MojiWordCardID(wordID: own[0].id), button: .good, seconds: 1, now: mine.end)
            #expect(foreign == nil)
        }
        #expect(Set(frequent.wordIDs) == Set((1...5).map { "t\($0)" }))
        #expect(frequent.wordIDs.allSatisfy { !MojiOwnWord.isOwnID($0) })
        #expect(frequent.summary?.deck == .frequent)
    }

    @Test("Scheduling, daily limits and day counts of my cards stay apart from the deck")
    func schedulingIsSeparate() async throws {
        let directory = Support.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let decks = decks(at: directory)
        _ = await decks.frequent.activate()
        var frequentOptions = MojiWordOptions.standard
        frequentOptions.newPerDay = 2
        await decks.frequent.setOptions(frequentOptions, now: Support.now)
        let own = await addCards(4, to: decks.mine)

        #expect(await decks.frequent.currentSnapshot(now: Support.now).queue.new == 2)
        let mineBefore = await decks.mine.currentSnapshot(now: Support.now)
        #expect(mineBefore.queue.new == 4)
        #expect(mineBefore.options.newPerDay == MojiWordDefaults.newPerDay)

        let first = try #require(card(await decks.mine.startSession(.deck, now: Support.now)))
        #expect(first.id.wordID == own[0].id)
        _ = await decks.mine.answer(first.id, button: .easy, seconds: 3, now: Support.now)
        _ = await decks.mine.endSession(now: Support.now)
        await decks.mine.flush()

        let frequent = await decks.frequent.currentSnapshot(now: Support.now)
        let mine = await decks.mine.currentSnapshot(now: Support.now)
        #expect(frequent.cards.isEmpty)
        #expect(frequent.todayStats.answers == 0)
        #expect(frequent.queue.new == 2)
        #expect(frequent.progress.words == 5)
        #expect(mine.todayStats.newCards == 1)
        #expect(mine.card(first.id).phase == .review)
        #expect(mine.cards.keys.allSatisfy { MojiOwnWord.isOwnID(MojiWordCardID(key: $0)?.wordID ?? "") })
        #expect(mine.queue.new == 3)
        #expect(mine.progress.words == 4)
        #expect(mine.progress.seenWords == 1)

        let files = Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
        #expect(files.isSuperset(of: ["words.mine.json", "words.mine-cards.json", "words.mine-days.json", "words.mine-history.json", "words.options.json"]))
        #expect(!files.contains("words.cards.json"))
        #expect(!files.contains("words.days.json"))
    }

    @Test("My cards, their progress and their options survive a restart")
    func persistence() async throws {
        let directory = Support.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let own: [MojiOwnWord]
        let answered: MojiWordCard
        let today: Int
        do {
            let decks = decks(at: directory)
            own = await addCards(2, to: decks.mine)
            var options = MojiWordOptions.standard
            options.reverseCards = true
            await decks.mine.setOptions(options, now: Support.now)
            let first = try #require(card(await decks.mine.startSession(.deck, now: Support.now)))
            _ = await decks.mine.answer(first.id, button: .good, seconds: 4, now: Support.now)
            _ = await decks.mine.endSession(now: Support.now)
            let snapshot = await decks.mine.currentSnapshot(now: Support.now)
            answered = snapshot.card(first.id)
            today = snapshot.today
        }

        let reopened = decks(at: directory)
        let mine = await reopened.mine.activate()
        #expect(mine.catalog.words.map(\.id) == own.map(\.id))
        #expect(mine.catalog.word(own[0].id)?.written == own[0].written)
        #expect(mine.catalog.word(own[1].id)?.english == own[1].meaning)
        #expect(mine.options.reverseCards)
        #expect(mine.card(MojiWordCardID(wordID: own[0].id)) == answered)
        #expect(mine.dayStats(today).newCards == 1)
        let history = await reopened.mine.history(wordID: own[0].id)
        #expect(history[MojiWordCardID(wordID: own[0].id)]?.count == 1)
        #expect(await reopened.frequent.activate().options.reverseCards == false)

        let data = try Data(contentsOf: directory.appendingPathComponent("words.mine.json"))
        let envelope = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(envelope["version"] as? Int == 1)
        #expect((envelope["value"] as? [Any])?.count == 2)
    }

    @Test("reloadFromDisk reads files replaced on disk and drops the open session")
    func reloadFromDisk() async throws {
        let directory = Support.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let decks = decks(at: directory)
        let own = await addCards(2, to: decks.mine)
        _ = await decks.mine.startSession(.deck, now: Support.now)
        #expect(await decks.mine.currentSnapshot(now: Support.now).hasSession)

        let imported = MojiOwnWord(
            id: "my-imported",
            input: MojiOwnWordInput(written: "海", reading: "うみ", meaning: "sea"),
            at: Support.now
        )
        var options = MojiWordOptions.standard
        options.newPerDay = 3
        let resources = MojiWordResourceRepository(store: decks.store, deck: .mine)
        await resources.saveOwnWords([imported])
        await resources.saveCards([imported.id: Support.review(dueDay: 9_000)])
        await resources.saveOptions(options)

        await decks.mine.reloadFromDisk(now: Support.now)
        let snapshot = await decks.mine.currentSnapshot(now: Support.now)
        #expect(snapshot.catalog.words.map(\.id) == ["my-imported"])
        #expect(snapshot.catalog.word(own[0].id) == nil)
        #expect(snapshot.card(MojiWordCardID(wordID: "my-imported")).phase == .review)
        #expect(snapshot.options.newPerDay == 3)
        #expect(!snapshot.hasSession)
        #expect(await decks.mine.step(now: Support.now) == nil)
    }

    @Test("A history save still waiting does not overwrite what reloadFromDisk read")
    func reloadCancelsPendingSave() async throws {
        let directory = Support.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let decks = decks(at: directory)
        let own = await addCards(1, to: decks.mine)
        let first = try #require(card(await decks.mine.startSession(.deck, now: Support.now)))
        _ = await decks.mine.answer(first.id, button: .good, seconds: 2, now: Support.now)

        await MojiWordResourceRepository(store: decks.store, deck: .mine).saveHistory([:])
        await decks.mine.reloadFromDisk(now: Support.now)
        try await Task.sleep(for: .milliseconds(2_600))

        let fresh = self.decks(at: directory)
        #expect(await fresh.mine.history(wordID: own[0].id).isEmpty)
    }

    @Test("Old Words data still loads, and My cards starts empty beside it")
    func oldWordsData() async throws {
        let directory = Support.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Support.writeEnvelope(#"{"t1":{"p":"review","i":12,"e":2500,"dd":9000,"n":3},"t2":{"p":"new","f":2}}"#, name: "words.cards.json", in: directory)
        try Support.writeEnvelope(#"{"newPerDay":7,"reverseCards":true}"#, name: "words.options.json", in: directory)
        try Support.writeEnvelope(#"[{"d":5,"nc":3}]"#, name: "words.days.json", in: directory)
        try Support.writeEnvelope(#"{"t2":"ask about it"}"#, name: "words.notes.json", in: directory)
        try Support.writeEnvelope(#"{"t1":[{"a":100,"b":3,"k":1,"i":12}]}"#, name: "words.history.json", in: directory)

        let decks = decks(at: directory)
        let frequent = await decks.frequent.activate()
        #expect(frequent.card(Support.id(1)).interval == 12)
        #expect(frequent.card(Support.id(2)).flag == .orange)
        #expect(frequent.options.newPerDay == 7)
        #expect(frequent.options.reverseCards)
        #expect(frequent.dayStats(5).newCards == 3)
        #expect(frequent.notes["t2"] == "ask about it")
        #expect(await decks.frequent.history(wordID: "t1")[Support.id(1)]?.count == 1)

        let mine = await decks.mine.activate()
        #expect(mine.isLoaded)
        #expect(mine.catalog.isEmpty)
        #expect(mine.cards.isEmpty)
        #expect(mine.options == .standard)
        #expect(mine.notes.isEmpty)

        _ = await addCards(2, to: decks.mine)
        await decks.mine.resetAll(now: Support.now)
        let reopened = self.decks(at: directory)
        let again = await reopened.frequent.activate()
        #expect(again.card(Support.id(1)).interval == 12)
        #expect(again.options.newPerDay == 7)
        #expect(again.notes["t2"] == "ask about it")
        #expect(await reopened.mine.activate().catalog.words.count == 2)
    }

    @Test("A broken card in the file costs only itself")
    func brokenCardsAreDropped() async throws {
        let directory = Support.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Support.writeEnvelope(
            #"[{"id":"my-1","written":"猫","reading":"ねこ","meaning":"cat","sentence":[{"surface":"猫","reading":"ねこ","target":true},{"surface":""},{"surface":"だ"}],"translation":"It's a cat.","createdAt":10},"#
                + #"{"id":"my-2","written":"犬"},{"id":"w123","written":"鳥","meaning":"bird"},{"oops":true},"#
                + #"{"id":"my-1","written":"猫","meaning":"twice"},{"id":"my-3","written":"魚","meaning":"fish","future":"field"}]"#,
            name: "words.mine.json",
            in: directory
        )

        let mine = await decks(at: directory).mine.activate()
        #expect(mine.catalog.words.map(\.id) == ["my-1", "my-3"])
        let cat = try #require(mine.catalog.word("my-1"))
        #expect(cat.english == "cat")
        #expect(cat.reading == "ねこ")
        let sentence = try #require(cat.sentences.first)
        #expect(sentence.tokens.map(\.surface) == ["猫", "だ"])
        #expect(sentence.tokens.first?.isTarget == true)
        #expect(sentence.translation(in: .en) == "It's a cat.")
        #expect(mine.catalog.word("my-3")?.reading == "")
    }
}
