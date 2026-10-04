import Foundation
import Testing
@testable import Moji

@Suite("Words study sessions")
struct MojiWordRepositoryTests {
    private typealias Support = MojiWordTestSupport

    private func card(_ step: MojiWordStudyStep?) -> MojiWordStudyCard? {
        guard case .card(let card) = step else { return nil }
        return card
    }

    private func summary(_ step: MojiWordStudyStep?) -> MojiWordSessionSummary? {
        guard case .finished(let summary) = step else { return nil }
        return summary
    }

    @Test("A full pass: every new card learned, counted for the day and kept after a restart")
    func fullPass() async throws {
        let directory = Support.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let catalog = Support.catalog(count: 5)
        let repository = Support.repository(at: directory, catalog: catalog)
        let start = await repository.activate()
        #expect(start.isLoaded)
        #expect(start.queue.new == 5)

        var now = Support.now
        var step: MojiWordStudyStep? = await repository.startSession(.deck, now: now)
        var answers = 0
        while let current = card(step), answers < 50 {
            #expect(current.delays[.good] != nil)
            now = now.addingTimeInterval(5)
            step = await repository.answer(current.id, button: .good, seconds: 4, now: now)
            answers += 1
        }
        let done = try #require(summary(step))
        #expect(done.isComplete)
        #expect(done.answered == 10)
        #expect(done.newCards == 5)
        #expect(done.correct == 10)
        #expect(done.seconds == 40)
        #expect(answers == 10)

        let snapshot = await repository.currentSnapshot(now: now)
        #expect(snapshot.todayStats.newCards == 5)
        #expect(snapshot.todayStats.learnAnswers == 10)
        #expect(snapshot.queue.total == 0)
        #expect(!snapshot.hasSession)
        await repository.flush()

        let reloaded = await Support.repository(at: directory, catalog: catalog).activate()
        for index in 1...5 {
            let saved = reloaded.card(Support.id(index))
            #expect(saved.phase == .review)
            #expect(saved.interval == 1)
        }
        #expect(reloaded.dayStats(snapshot.today).newCards == 5)
        let history = await Support.repository(at: directory, catalog: catalog).history(wordID: "t1")
        #expect(history[Support.id(1)]?.count == 2)
    }

    @Test("Undo restores the card, the counts and the session, and shows that card again")
    func undo() async throws {
        let directory = Support.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = Support.repository(at: directory, catalog: Support.catalog(count: 3))
        _ = await repository.activate()

        let first = try #require(card(await repository.startSession(.deck, now: Support.now)))
        #expect(first.id == Support.id(1))
        #expect(!first.canUndo)
        let second = try #require(card(await repository.answer(first.id, button: .again, seconds: 3, now: Support.now)))
        #expect(second.id == Support.id(2))
        #expect(second.canUndo)

        let restored = try #require(card(await repository.undo(now: Support.now)))
        #expect(restored.id == Support.id(1))
        #expect(restored.card == .fresh)
        #expect(!restored.canUndo)
        let snapshot = await repository.currentSnapshot(now: Support.now)
        #expect(snapshot.todayStats.newCards == 0)
        #expect(snapshot.todayStats.againCount == 0)
        #expect(snapshot.card(Support.id(1)) == .fresh)
        #expect(await repository.undo(now: Support.now) == nil)

        let again = try #require(card(await repository.answer(restored.id, button: .good, seconds: 2, now: Support.now)))
        #expect(again.id == Support.id(2))
    }

    @Test("A leech with the suspend action leaves the queue at once")
    func leechSuspends() async throws {
        let directory = Support.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = Support.repository(at: directory, catalog: Support.catalog(count: 2))
        _ = await repository.activate()
        var options = MojiWordOptions.standard
        options.leechThreshold = 1
        options.leechAction = .suspend
        options.newPerDay = 0
        await repository.setOptions(options, now: Support.now)
        await repository.reschedule([Support.id(1)], inDays: 0, now: Support.now)

        let review = try #require(card(await repository.startSession(.deck, now: Support.now)))
        #expect(review.kind == .review)
        let result = try #require(summary(await repository.answer(review.id, button: .again, seconds: 5, now: Support.now)))
        #expect(result.leeches == ["t1"])
        let snapshot = await repository.currentSnapshot(now: Support.now)
        #expect(snapshot.card(Support.id(1)).isSuspended)
        #expect(snapshot.card(Support.id(1)).isLeech)
        #expect(snapshot.states.suspended == 1)
    }

    @Test("Review forgotten replays failed cards without touching their schedule")
    func forgottenCram() async throws {
        let directory = Support.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = Support.repository(at: directory, catalog: Support.catalog(count: 3))
        _ = await repository.activate()
        var options = MojiWordOptions.standard
        options.newPerDay = 0
        await repository.setOptions(options, now: Support.now)
        await repository.reschedule([Support.id(2)], inDays: 0, now: Support.now)

        let lapse = try #require(card(await repository.startSession(.deck, now: Support.now)))
        _ = await repository.answer(lapse.id, button: .again, seconds: 2, now: Support.now)
        _ = await repository.endSession(now: Support.now)
        let before = await repository.currentSnapshot(now: Support.now).card(Support.id(2))
        #expect(before.phase == .relearning)

        let later = Support.now.addingTimeInterval(60)
        #expect(await repository.studyCount(for: .forgotten(days: 1), now: later).review == 1)
        let cram = try #require(card(await repository.startSession(.forgotten(days: 1), now: later)))
        #expect(cram.isCram)
        #expect(cram.delays.isEmpty)
        let retry = try #require(card(await repository.answer(cram.id, button: .again, seconds: 1, now: later)))
        #expect(retry.id == cram.id)
        let finished = try #require(summary(await repository.answer(retry.id, button: .good, seconds: 1, now: later)))
        #expect(finished.answered == 2)
        let after = await repository.currentSnapshot(now: later)
        #expect(after.card(Support.id(2)) == before)
        #expect(after.todayStats.cramAnswers == 2)
    }

    @Test("Mark a section as known, then reset it")
    func sectionMarks() async throws {
        let directory = Support.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let catalog = Support.catalog(count: 20)
        let repository = Support.repository(at: directory, catalog: catalog)
        _ = await repository.activate()
        let section = try #require(catalog.section(1))

        await repository.markKnown(wordIDs: section.wordIDs, now: Support.now)
        var snapshot = await repository.currentSnapshot(now: Support.now)
        let known = try #require(snapshot.sections[1])
        #expect(known.isKnown)
        #expect(known.matureFraction == 1)
        #expect(snapshot.sections[2]?.isUntouched == true)
        #expect(snapshot.queue.new == 10)
        #expect(snapshot.queue.review == 0)

        await repository.forget(wordIDs: section.wordIDs, now: Support.now)
        snapshot = await repository.currentSnapshot(now: Support.now)
        #expect(snapshot.sections[1]?.isUntouched == true)
        #expect(snapshot.queue.new == 20)
    }

    @Test("Card actions: bury, flag, note, set due date")
    func cardActions() async throws {
        let directory = Support.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = Support.repository(at: directory, catalog: Support.catalog(count: 2))
        _ = await repository.activate()
        let first = Support.id(1)

        await repository.bury([first], now: Support.now)
        var snapshot = await repository.currentSnapshot(now: Support.now)
        #expect(snapshot.card(first).isBuried(on: snapshot.today))
        #expect(snapshot.queue.new == 1)
        await repository.unbury([first], now: Support.now)

        await repository.setFlag(.blue, cards: [first], now: Support.now)
        await repository.setNote("  ask about 語  ", wordID: "t1", now: Support.now)
        await repository.reschedule([first], inDays: 7, now: Support.now)
        snapshot = await repository.currentSnapshot(now: Support.now)
        #expect(snapshot.card(first).flag == .blue)
        #expect(snapshot.notes["t1"] == "ask about 語")
        #expect(snapshot.card(first).dueDay == snapshot.today + 7)
        #expect(snapshot.states.flagged == 1)

        let reloaded = await Support.repository(at: directory, catalog: Support.catalog(count: 2)).activate()
        #expect(reloaded.card(first).flag == .blue)
        #expect(reloaded.notes["t1"] == "ask about 語")
    }

    @Test("Saved words data from an older build loads; broken entries cost only themselves")
    func oldData() async throws {
        let directory = Support.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Support.writeEnvelope(
            #"{"t1":{"p":"review","i":12,"e":2500,"dd":9000,"n":3},"t2":{"p":"teleported"},"t3":{"p":"new","f":3}}"#,
            name: "words.cards.json",
            in: directory
        )
        try Support.writeEnvelope(#"{"newPerDay":7,"leechAction":"explode","learningSteps":[-1,2]}"#, name: "words.options.json", in: directory)
        try Support.writeEnvelope(#"[{"d":5,"nc":3},{"broken":true}]"#, name: "words.days.json", in: directory)

        let snapshot = await Support.repository(at: directory, catalog: Support.catalog(count: 3)).activate()
        #expect(snapshot.card(Support.id(1)).interval == 12)
        #expect(snapshot.card(Support.id(1)).phase == .review)
        #expect(snapshot.card(Support.id(2)) == .fresh)
        #expect(snapshot.card(Support.id(3)).flag == .green)
        #expect(snapshot.options.newPerDay == 7)
        #expect(snapshot.options.leechAction == .tagOnly)
        #expect(snapshot.options.learningSteps == [2])
        #expect(snapshot.options.reviewsPerDay == 200)
        #expect(snapshot.dayStats(5).newCards == 3)
    }

    @Test("A month of daily study: limits hold and a word's two cards never meet on one day")
    func monthOfStudy() async throws {
        let directory = Support.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = Support.repository(at: directory, catalog: Support.catalog(count: 60))
        _ = await repository.activate()
        var options = MojiWordOptions.standard
        options.reverseCards = true
        options.newPerDay = 10
        options.reviewsPerDay = 40
        await repository.setOptions(options, now: Support.now)

        var morning = Support.now
        var totalAnswers = 0
        for dayIndex in 0..<30 {
            var now = morning
            var kindsByWord: [String: Set<MojiWordCardKind>] = [:]
            var newShown = 0
            var answers = 0
            var step: MojiWordStudyStep? = await repository.startSession(.deck, now: now)
            while case .card(let card) = step, answers < 600 {
                kindsByWord[card.id.wordID, default: []].insert(card.id.kind)
                if card.card.isNew {
                    newShown += 1
                }
                let button: MojiWordButton = (answers + dayIndex) % 6 == 0 ? .again : .good
                now = now.addingTimeInterval(40)
                step = await repository.answer(card.id, button: button, seconds: 6, now: now)
                answers += 1
            }
            let snapshot = await repository.currentSnapshot(now: now)
            let stats = snapshot.todayStats
            #expect(newShown <= 10, "day \(dayIndex)")
            #expect(stats.newCards + stats.reviewCards <= 40, "day \(dayIndex)")
            #expect(kindsByWord.values.allSatisfy { $0.count == 1 }, "day \(dayIndex)")
            #expect(summary(step) != nil, "day \(dayIndex)")
            totalAnswers += answers
            morning = morning.addingTimeInterval(86_400)
        }
        let end = await repository.currentSnapshot(now: morning)
        #expect(totalAnswers > 300)
        #expect(end.states.young + end.states.mature > 30)
        #expect(end.cards.keys.contains { $0.hasSuffix("~r") })
    }

    @Test("Options round-trip and keep their defaults for anything missing")
    func optionsDecoding() throws {
        var options = MojiWordOptions.standard
        options.reverseCards = true
        options.frontFurigana = .exceptWord
        options.learningSteps = [1, 10, 60]
        let data = try JSONEncoder().encode(options)
        #expect(try JSONDecoder().decode(MojiWordOptions.self, from: data) == options)

        let empty = try JSONDecoder().decode(MojiWordOptions.self, from: Data("{}".utf8))
        #expect(empty == .standard)
    }
}
