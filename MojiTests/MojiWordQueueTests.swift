import Foundation
import Testing
@testable import Moji

@Suite("Words queue and daily limits")
struct MojiWordQueueTests {
    private typealias Support = MojiWordTestSupport

    private func build(
        _ catalog: MojiWordCatalog,
        cards: [String: MojiWordCard] = [:],
        options: MojiWordOptions = .standard,
        day: MojiWordDayStats? = nil,
        scope: MojiWordScope = .deck,
        at date: Date = MojiWordTestSupport.now
    ) -> MojiWordQueue {
        let context = Support.context(options, at: date)
        return MojiWordQueue.build(
            scope: scope,
            catalog: catalog,
            cards: cards,
            day: day ?? MojiWordDayStats(day: context.today),
            context: context
        )
    }

    private var today: Int {
        Support.context().today
    }

    @Test("New cards come in frequency order up to the daily limit")
    func newLimit() {
        let catalog = Support.catalog(count: 50)
        var options = MojiWordOptions.standard
        options.newPerDay = 5
        let queue = build(catalog, options: options)
        #expect(queue.counts.new == 5)
        #expect(queue.main.map(\.id.wordID) == ["t1", "t2", "t3", "t4", "t5"])
        #expect(queue.main.allSatisfy { $0.kind == .new })

        var day = MojiWordDayStats(day: today)
        day.newCards = 3
        #expect(build(catalog, options: options, day: day).counts.new == 2)
        day.extraNew = 4
        #expect(build(catalog, options: options, day: day).counts.new == 6)
        day.newCards = 9
        day.extraNew = 4
        #expect(build(catalog, options: options, day: day).counts.new == 0)
    }

    @Test("The review limit caps reviews and leaves new cards only the room that is left")
    func reviewLimit() {
        let catalog = Support.catalog(count: 40)
        var cards: [String: MojiWordCard] = [:]
        for index in 1...12 {
            cards[Support.id(index).key] = Support.review(dueDay: today)
        }
        var options = MojiWordOptions.standard
        options.reviewsPerDay = 10
        let full = build(catalog, cards: cards, options: options)
        #expect(full.counts.review == 10)
        #expect(full.counts.new == 0)

        options.reviewsPerDay = 15
        let room = build(catalog, cards: cards, options: options)
        #expect(room.counts.review == 12)
        #expect(room.counts.new == 3)

        var day = MojiWordDayStats(day: today)
        day.reviewCards = 4
        day.newCards = 1
        let later = build(catalog, cards: cards, options: options, day: day)
        #expect(later.counts.review == 10)
        #expect(later.counts.new == 0)
    }

    @Test("Due learning cards come first, then the main queue, then learning due within 20 minutes")
    func learningFirst() {
        let catalog = Support.catalog(count: 5)
        var options = MojiWordOptions.standard
        options.newPerDay = 0
        let now = Support.now

        var cards = [
            Support.id(1).key: Support.learning(dueAt: now.addingTimeInterval(-60)),
            Support.id(2).key: Support.review(dueDay: today)
        ]
        #expect(build(catalog, cards: cards, options: options).next(at: now)?.id == Support.id(1))

        cards[Support.id(1).key] = Support.learning(dueAt: now.addingTimeInterval(300))
        let waiting = build(catalog, cards: cards, options: options)
        #expect(waiting.next(at: now)?.id == Support.id(2))
        #expect(waiting.counts.learning == 1)
        #expect(waiting.counts.review == 1)

        cards[Support.id(2).key] = nil
        #expect(build(catalog, cards: cards, options: options).next(at: now)?.id == Support.id(1))

        cards[Support.id(1).key] = Support.learning(dueAt: now.addingTimeInterval(1_800))
        let later = build(catalog, cards: cards, options: options)
        #expect(later.next(at: now) == nil)
        #expect(later.nextLearningAt == now.addingTimeInterval(1_800))
        #expect(later.laterToday == 1)
    }

    @Test("New cards are spread through the reviews, or put before or after them")
    func newReviewMix() {
        let catalog = Support.catalog(count: 20)
        var cards: [String: MojiWordCard] = [:]
        for index in 1...4 {
            cards[Support.id(index).key] = Support.review(dueDay: today)
        }
        var options = MojiWordOptions.standard
        options.newPerDay = 1

        let mixed = build(catalog, cards: cards, options: options)
        #expect(mixed.main.map(\.kind) == [.review, .review, .new, .review, .review])

        options.newReviewMix = .newFirst
        #expect(build(catalog, cards: cards, options: options).main.first?.kind == .new)
        options.newReviewMix = .reviewsFirst
        #expect(build(catalog, cards: cards, options: options).main.last?.kind == .new)

        let spread = MojiWordQueue.intersperse(
            (1...6).map { MojiWordQueueEntry(id: Support.id($0), kind: .review) },
            (7...8).map { MojiWordQueueEntry(id: Support.id($0), kind: .new) }
        )
        #expect(spread.map(\.kind) == [.review, .review, .new, .review, .review, .new, .review, .review])
    }

    @Test("Reviews: most overdue first, then a random order that stays put all day")
    func reviewOrder() {
        let catalog = Support.catalog(count: 20)
        var options = MojiWordOptions.standard
        options.newPerDay = 0
        let cards = [
            Support.id(1).key: Support.review(dueDay: today, interval: 3),
            Support.id(2).key: Support.review(dueDay: today - 3, interval: 9),
            Support.id(3).key: Support.review(dueDay: today - 1, interval: 1)
        ]
        #expect(build(catalog, cards: cards, options: options).main.map(\.id.wordID) == ["t2", "t3", "t1"])

        options.reviewOrder = .ascendingIntervals
        #expect(build(catalog, cards: cards, options: options).main.map(\.id.wordID) == ["t3", "t1", "t2"])
        options.reviewOrder = .descendingIntervals
        #expect(build(catalog, cards: cards, options: options).main.map(\.id.wordID) == ["t2", "t1", "t3"])

        var same: [String: MojiWordCard] = [:]
        for index in 1...12 {
            same[Support.id(index).key] = Support.review(dueDay: today)
        }
        options.reviewOrder = .dueThenRandom
        let first = build(catalog, cards: same, options: options).main.map(\.id)
        let second = build(catalog, cards: same, options: options).main.map(\.id)
        #expect(first == second)
        #expect(first.map(\.wordID) != (1...12).map { "t\($0)" })
        options.reviewOrder = .dueThenFrequency
        #expect(build(catalog, cards: same, options: options).main.map(\.id.wordID) == (1...12).map { "t\($0)" })
    }

    @Test("Random new order is shuffled but stable")
    func randomNewOrder() {
        let catalog = Support.catalog(count: 60)
        var options = MojiWordOptions.standard
        options.newOrder = .random
        let first = build(catalog, options: options).main.map(\.id.wordID)
        #expect(first.count == 20)
        #expect(first == build(catalog, options: options).main.map(\.id.wordID))
        #expect(first != (1...20).map { "t\($0)" })
    }

    @Test("Reverse cards: a word's two cards never come on the same day")
    func reverseSiblings() {
        let catalog = Support.catalog(count: 3)
        var options = MojiWordOptions.standard
        options.reverseCards = true

        let fresh = build(catalog, options: options)
        #expect(fresh.counts.new == 3)
        #expect(fresh.main.allSatisfy { $0.id.kind == .recognition })

        var answered = Support.learning(dueAt: Support.now.addingTimeInterval(600))
        answered.lastAnsweredDay = today
        let cards = [Support.id(1).key: answered]
        let sameDay = build(catalog, cards: cards, options: options)
        #expect(!sameDay.main.contains { $0.id.wordID == "t1" })
        #expect(sameDay.learning.map(\.id) == [Support.id(1)])

        var graduated = Support.review(dueDay: today + 3, interval: 3)
        graduated.lastAnsweredDay = today
        let tomorrow = build(
            catalog,
            cards: [Support.id(1).key: graduated],
            options: options,
            at: Support.now.addingTimeInterval(86_400)
        )
        #expect(tomorrow.main.contains { $0.id == Support.id(1, .recall) })

        let bothDue = [
            Support.id(1).key: Support.review(dueDay: today),
            Support.id(1, .recall).key: Support.review(dueDay: today)
        ]
        var reviewsOnly = options
        reviewsOnly.newPerDay = 0
        #expect(build(catalog, cards: bothDue, options: reviewsOnly).main.filter { $0.id.wordID == "t1" }.count == 1)
        reviewsOnly.burySiblings = false
        #expect(build(catalog, cards: bothDue, options: reviewsOnly).main.filter { $0.id.wordID == "t1" }.count == 2)
    }

    @Test("Suspended cards stay out; buried ones come back the next day")
    func suspendedAndBuried() {
        let catalog = Support.catalog(count: 3)
        var options = MojiWordOptions.standard
        options.newPerDay = 0
        var suspended = Support.review(dueDay: today)
        suspended.isSuspended = true
        var buried = Support.review(dueDay: today)
        buried.buriedUntil = today + 1
        let cards = [Support.id(1).key: suspended, Support.id(2).key: buried, Support.id(3).key: Support.review(dueDay: today)]
        #expect(build(catalog, cards: cards, options: options).main.map(\.id.wordID) == ["t3"])
        let tomorrow = build(catalog, cards: cards, options: options, at: Support.now.addingTimeInterval(86_400))
        #expect(Set(tomorrow.main.map(\.id.wordID)) == ["t2", "t3"])
    }

    @Test("Study a section: its new cards plus all that is due; one section only keeps to it")
    func sectionScopes() {
        let catalog = Support.catalog(count: 30)
        let cards = [Support.id(1).key: Support.review(dueDay: today)]
        let section = build(catalog, cards: cards, scope: .section(2))
        #expect(section.main.contains { $0.id == Support.id(1) })
        #expect(section.main.filter { $0.kind == .new }.map(\.id.wordID) == (11...20).map { "t\($0)" })

        let only = build(catalog, cards: cards, scope: .sectionOnly(2))
        #expect(!only.main.contains { $0.id == Support.id(1) })
        #expect(only.counts.new == 10)
    }

    @Test("Review ahead takes cards due in the next days and ignores the limits")
    func reviewAhead() {
        let catalog = Support.catalog(count: 10)
        var options = MojiWordOptions.standard
        options.reviewsPerDay = 0
        let cards = [
            Support.id(1).key: Support.review(dueDay: today + 2),
            Support.id(2).key: Support.review(dueDay: today + 5)
        ]
        let ahead = build(catalog, cards: cards, options: options, scope: .reviewAhead(days: 3))
        #expect(ahead.main.map(\.id.wordID) == ["t1"])
        #expect(ahead.counts.new == 0)
        #expect(build(catalog, cards: cards, options: options).main.isEmpty)
    }
}
