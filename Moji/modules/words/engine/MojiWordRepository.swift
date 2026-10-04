import Foundation

extension MojiWordCatalog: Equatable {
    static func == (lhs: MojiWordCatalog, rhs: MojiWordCatalog) -> Bool {
        lhs === rhs
    }
}

struct MojiWordRepositorySnapshot: Equatable, Sendable {
    let isLoaded: Bool
    let catalog: MojiWordCatalog
    let cards: [String: MojiWordCard]
    let options: MojiWordOptions
    let notes: [String: String]
    let days: [Int: MojiWordDayStats]
    let today: Int
    let clock: Date
    let queue: MojiWordQueueCounts
    let nextLearningAt: Date?
    let learningLater: Int
    let sections: [Int: MojiWordSectionStats]
    let states: MojiWordStateCounts
    let progress: MojiWordDeckProgress
    let hasSession: Bool

    static let empty = MojiWordRepositorySnapshot(
        isLoaded: false,
        catalog: .empty,
        cards: [:],
        options: .standard,
        notes: [:],
        days: [:],
        today: 0,
        clock: Date(),
        queue: .zero,
        nextLearningAt: nil,
        learningLater: 0,
        sections: [:],
        states: .zero,
        progress: .zero,
        hasSession: false
    )

    func card(_ id: MojiWordCardID) -> MojiWordCard {
        cards[id.key] ?? .fresh
    }

    func dayStats(_ day: Int) -> MojiWordDayStats {
        days[day] ?? MojiWordDayStats(day: day)
    }

    var todayStats: MojiWordDayStats {
        dayStats(today)
    }
}

struct MojiWordStudyCard: Equatable, Sendable {
    let id: MojiWordCardID
    let word: MojiWord
    let card: MojiWordCard
    let kind: MojiWordQueueKind
    let sentenceIndex: Int
    let delays: [MojiWordButton: MojiWordDelay]
    let counts: MojiWordQueueCounts
    let isCram: Bool
    let canUndo: Bool
    let answered: Int

    var sentence: MojiWordSentence? {
        word.sentence(at: sentenceIndex)
    }

    var presentationID: String {
        "\(id.key)#\(answered)#\(card.reps)"
    }
}

struct MojiWordSessionSummary: Equatable, Sendable {
    let scope: MojiWordScope
    let answered: Int
    let correct: Int
    let again: Int
    let newCards: Int
    let seconds: Double
    let startedAt: Date
    let finishedAt: Date
    let learningLater: Int
    let nextLearningAt: Date?
    let leeches: [String]
    let isComplete: Bool
    let remaining: MojiWordQueueCounts
}

enum MojiWordStudyStep: Equatable, Sendable {
    case card(MojiWordStudyCard)
    case finished(MojiWordSessionSummary)
}

struct MojiWordSessionCounters: Equatable, Sendable {
    var answered = 0
    var correct = 0
    var again = 0
    var newCards = 0
    var seconds: Double = 0
    var leeches: [String] = []
}

private struct MojiWordUndoEntry: Sendable {
    let id: MojiWordCardID
    let previousCard: MojiWordCard?
    let day: Int
    let previousDay: MojiWordDayStats?
    let previousHistory: [MojiWordReview]?
    let counters: MojiWordSessionCounters
    let cramQueue: [MojiWordCardID]
    let pinned: MojiWordCardID?
}

private struct MojiWordSessionState: Sendable {
    let id: UUID
    let scope: MojiWordScope
    let startedAt: Date
    var counters = MojiWordSessionCounters()
    var cramQueue: [MojiWordCardID] = []
    var undo: [MojiWordUndoEntry] = []
    var pinned: MojiWordCardID?
}

actor MojiWordRepository {
    static let historyLimit = 30
    static let undoLimit = 50
    static let cramRetryGap = 2

    private let resources: MojiWordResourceRepository
    private let catalogLoader: @Sendable () -> MojiWordCatalog
    private let calendar: Calendar
    private let learningFuzz: @Sendable () -> Double

    private var catalog = MojiWordCatalog.empty
    private var cards: [String: MojiWordCard] = [:]
    private var history: [String: [MojiWordReview]] = [:]
    private var days: [Int: MojiWordDayStats] = [:]
    private var options = MojiWordOptions.standard
    private var notes: [String: String] = [:]
    private var session: MojiWordSessionState?

    private var today = 0
    private var clock = Date()
    private var deckQueue = MojiWordQueue.empty
    private var sectionStats: [Int: MojiWordSectionStats] = [:]
    private var stateCounts = MojiWordStateCounts.zero
    private var deckProgress = MojiWordDeckProgress.zero

    private var isLoaded = false
    private var loadTask: Task<Void, Never>?
    private var historySave: Task<Void, Never>?
    private var publish: (@Sendable (MojiWordRepositorySnapshot) async -> Void)?

    init(
        resources: MojiWordResourceRepository,
        catalogLoader: @escaping @Sendable () -> MojiWordCatalog = { MojiWordCatalog.bundled() },
        calendar: Calendar = .current,
        learningFuzz: @escaping @Sendable () -> Double = { Double.random(in: 0..<1) }
    ) {
        self.resources = resources
        self.catalogLoader = catalogLoader
        self.calendar = calendar
        self.learningFuzz = learningFuzz
    }

    func setPublisher(_ publish: @escaping @Sendable (MojiWordRepositorySnapshot) async -> Void) {
        self.publish = publish
    }

    func activate() async -> MojiWordRepositorySnapshot {
        await ensureLoaded()
        return snapshot()
    }

    func currentSnapshot(now: Date) async -> MojiWordRepositorySnapshot {
        await ensureLoaded()
        recomputeDerived(now: now)
        return snapshot()
    }

    func startSession(_ scope: MojiWordScope, now: Date) async -> MojiWordStudyStep {
        await ensureLoaded()
        var state = MojiWordSessionState(id: UUID(), scope: scope, startedAt: now)
        if case .forgotten(let span) = scope {
            state.cramQueue = forgottenCards(within: span, now: now)
        }
        session = state
        await emit(now: now)
        return await resolveStep(now: now)
    }

    func step(now: Date) async -> MojiWordStudyStep? {
        await ensureLoaded()
        guard session != nil else { return nil }
        return await resolveStep(now: now)
    }

    func answer(
        _ id: MojiWordCardID,
        button: MojiWordButton,
        seconds: Double,
        now: Date
    ) async -> MojiWordStudyStep? {
        await ensureLoaded()
        guard var state = session, catalog.word(id.wordID) != nil else { return nil }

        let context = context(at: now)
        let previousDay = days[context.today]
        var dayStats = previousDay ?? MojiWordDayStats(day: context.today)
        let previousCard = cards[id.key]
        let card = previousCard ?? .fresh
        let spent = min(max(0, seconds), MojiWordDefaults.maximumAnswerSeconds)

        state.undo.append(
            MojiWordUndoEntry(
                id: id,
                previousCard: previousCard,
                day: context.today,
                previousDay: previousDay,
                previousHistory: history[id.key],
                counters: state.counters,
                cramQueue: state.cramQueue,
                pinned: state.pinned
            )
        )
        if state.undo.count > Self.undoLimit {
            state.undo.removeFirst(state.undo.count - Self.undoLimit)
        }

        let review: MojiWordReview
        if state.scope.isCram {
            dayStats.cramAnswers += 1
            review = MojiWordReview(
                at: now,
                button: button,
                kind: .cram,
                interval: card.interval,
                lastInterval: card.interval,
                easeFactor: card.easeFactor,
                seconds: spent
            )
            if let index = state.cramQueue.firstIndex(of: id) {
                state.cramQueue.remove(at: index)
            }
            if button == .again {
                state.cramQueue.insert(id, at: min(Self.cramRetryGap, state.cramQueue.count))
            }
        } else {
            let outcome = MojiWordScheduler.answer(
                card,
                id: id,
                button: button,
                context: context,
                learningFuzz: learningFuzz()
            )
            cards[id.key] = outcome.card
            record(card: card, button: button, into: &dayStats)
            if card.isNew {
                state.counters.newCards += 1
            }
            if outcome.becameLeech, !state.counters.leeches.contains(id.wordID) {
                state.counters.leeches.append(id.wordID)
            }
            review = MojiWordReview(
                at: now,
                button: button,
                kind: MojiWordScheduler.reviewKind(of: card),
                interval: Self.storedInterval(outcome.delay),
                lastInterval: Self.lastInterval(of: card),
                easeFactor: outcome.card.easeFactor,
                seconds: spent
            )
        }

        if button == .again {
            dayStats.againCount += 1
            state.counters.again += 1
        } else {
            state.counters.correct += 1
        }
        dayStats.seconds += spent
        state.counters.answered += 1
        state.counters.seconds += spent
        if state.pinned == id {
            state.pinned = nil
        }
        days[context.today] = dayStats
        appendHistory(review, for: id)
        session = state

        await resources.saveCards(cards)
        await resources.saveDays(days)
        scheduleHistorySave()
        await emit(now: now)
        return await resolveStep(now: now)
    }

    func undo(now: Date) async -> MojiWordStudyStep? {
        await ensureLoaded()
        guard var state = session, let entry = state.undo.popLast() else { return nil }
        cards[entry.id.key] = entry.previousCard
        days[entry.day] = entry.previousDay
        history[entry.id.key] = entry.previousHistory
        state.counters = entry.counters
        state.cramQueue = entry.cramQueue
        state.pinned = entry.id
        session = state

        await resources.saveCards(cards)
        await resources.saveDays(days)
        scheduleHistorySave()
        await emit(now: now)
        return await resolveStep(now: now)
    }

    func endSession(now: Date) async -> MojiWordSessionSummary? {
        await ensureLoaded()
        guard session != nil else { return nil }
        let summary = makeSummary(now: now, isComplete: false)
        session = nil
        await flushHistory()
        await emit(now: now)
        return summary
    }

    func setOptions(_ newOptions: MojiWordOptions, now: Date) async {
        await ensureLoaded()
        let sanitized = newOptions.sanitized()
        guard sanitized != options else { return }
        options = sanitized
        await resources.saveOptions(options)
        await emit(now: now)
    }

    func addToday(extraNew: Int, extraReviews: Int, now: Date) async {
        await ensureLoaded()
        let day = context(at: now).today
        var stats = days[day] ?? MojiWordDayStats(day: day)
        stats.extraNew = max(0, stats.extraNew + extraNew)
        stats.extraReviews = max(0, stats.extraReviews + extraReviews)
        days[day] = stats
        await resources.saveDays(days)
        await emit(now: now)
    }

    func markKnown(wordIDs: [String], now: Date) async {
        await ensureLoaded()
        let context = context(at: now)
        var changed = false
        for wordID in wordIDs {
            guard let word = catalog.word(wordID) else { continue }
            for id in MojiWordStats.cardIDs(of: word, options: options) {
                let card = cards[id.key] ?? .fresh
                guard !card.isMature || card.isSuspended else { continue }
                let known = MojiWordScheduler.knownCard(card, id: id, context: context)
                cards[id.key] = known
                appendHistory(manualReview(at: now, card: known, previous: card), for: id)
                changed = true
            }
        }
        guard changed else { return }
        await commitCardChange(now: now)
    }

    func forget(wordIDs: [String], now: Date) async {
        await ensureLoaded()
        var changed = false
        for wordID in wordIDs {
            for kind in MojiWordCardKind.allCases {
                let id = MojiWordCardID(wordID: wordID, kind: kind)
                guard let card = cards[id.key], !card.isNew || card.isSuspended || card.buriedUntil != nil else { continue }
                let reset = MojiWordScheduler.forgotten(card)
                cards[id.key] = reset.isUntouched ? nil : reset
                appendHistory(manualReview(at: now, card: reset, previous: card), for: id)
                changed = true
            }
        }
        guard changed else { return }
        await commitCardChange(now: now)
    }

    func setSuspended(_ suspended: Bool, cards ids: [MojiWordCardID], now: Date) async {
        await updateCards(ids, now: now) { card, _ in
            guard card.isSuspended != suspended else { return false }
            card.isSuspended = suspended
            return true
        }
    }

    func bury(_ ids: [MojiWordCardID], now: Date) async {
        let tomorrow = context(at: now).today + 1
        await updateCards(ids, now: now) { card, _ in
            guard card.buriedUntil != tomorrow else { return false }
            card.buriedUntil = tomorrow
            return true
        }
    }

    func unbury(_ ids: [MojiWordCardID], now: Date) async {
        await updateCards(ids, now: now) { card, _ in
            guard card.buriedUntil != nil else { return false }
            card.buriedUntil = nil
            return true
        }
    }

    func reschedule(_ ids: [MojiWordCardID], inDays days: Int, now: Date) async {
        await ensureLoaded()
        let context = context(at: now)
        var changed = false
        for id in ids where catalog.word(id.wordID) != nil {
            let card = cards[id.key] ?? .fresh
            let next = MojiWordScheduler.rescheduled(card, inDays: days, context: context)
            guard next != card else { continue }
            cards[id.key] = next
            appendHistory(manualReview(at: now, card: next, previous: card), for: id)
            changed = true
        }
        guard changed else { return }
        await commitCardChange(now: now)
    }

    func setFlag(_ flag: MojiWordFlag?, cards ids: [MojiWordCardID], now: Date) async {
        await updateCards(ids, now: now) { card, _ in
            guard card.flag != flag else { return false }
            card.flag = flag
            return true
        }
    }

    func setLeech(_ isLeech: Bool, cards ids: [MojiWordCardID], now: Date) async {
        await updateCards(ids, now: now) { card, _ in
            guard card.isLeech != isLeech else { return false }
            card.isLeech = isLeech
            return true
        }
    }

    func setNote(_ note: String, wordID: String, now: Date) async {
        await ensureLoaded()
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard notes[wordID] != (trimmed.isEmpty ? nil : trimmed) else { return }
        notes[wordID] = trimmed.isEmpty ? nil : trimmed
        await resources.saveNotes(notes)
        await emit(now: now)
    }

    func history(wordID: String) async -> [MojiWordCardID: [MojiWordReview]] {
        await ensureLoaded()
        var result: [MojiWordCardID: [MojiWordReview]] = [:]
        for kind in MojiWordCardKind.allCases {
            let id = MojiWordCardID(wordID: wordID, kind: kind)
            if let entries = history[id.key], !entries.isEmpty {
                result[id] = entries
            }
        }
        return result
    }

    func resetAll(now: Date) async {
        await ensureLoaded()
        cards = [:]
        history = [:]
        days = [:]
        session = nil
        historySave?.cancel()
        historySave = nil
        await resources.clearProgress()
        await emit(now: now)
    }

    func refreshClock(now: Date = Date()) async {
        await ensureLoaded()
        await emit(now: now)
    }

    func flush() async {
        await ensureLoaded()
        await flushHistory()
    }

    func studyCount(for scope: MojiWordScope, now: Date) async -> MojiWordQueueCounts {
        await ensureLoaded()
        let context = context(at: now)
        if case .forgotten(let span) = scope {
            return MojiWordQueueCounts(new: 0, learning: 0, review: forgottenCards(within: span, now: now).count)
        }
        return MojiWordQueue.build(
            scope: scope,
            catalog: catalog,
            cards: cards,
            day: days[context.today] ?? MojiWordDayStats(day: context.today),
            context: context
        ).counts
    }

    private func updateCards(
        _ ids: [MojiWordCardID],
        now: Date,
        _ change: (inout MojiWordCard, MojiWordCardID) -> Bool
    ) async {
        await ensureLoaded()
        var changed = false
        for id in ids where catalog.word(id.wordID) != nil {
            var card = cards[id.key] ?? .fresh
            guard change(&card, id) else { continue }
            cards[id.key] = card.isUntouched ? nil : card
            changed = true
        }
        guard changed else { return }
        await commitCardChange(now: now)
    }

    private func commitCardChange(now: Date) async {
        await resources.saveCards(cards)
        scheduleHistorySave()
        await emit(now: now)
    }

    private func record(card: MojiWordCard, button: MojiWordButton, into stats: inout MojiWordDayStats) {
        switch card.phase {
        case .new:
            stats.newCards += 1
            stats.learnAnswers += 1
        case .learning:
            if !card.isIntradayLearning {
                stats.reviewCards += 1
            }
            stats.learnAnswers += 1
        case .review:
            stats.reviewCards += 1
            stats.reviewAnswers += 1
            switch (card.interval >= MojiWordScheduler.matureInterval, button.isPass) {
            case (true, true): stats.maturePassed += 1
            case (true, false): stats.matureFailed += 1
            case (false, true): stats.youngPassed += 1
            case (false, false): stats.youngFailed += 1
            }
        case .relearning:
            if !card.isIntradayLearning {
                stats.reviewCards += 1
            }
            stats.relearnAnswers += 1
        }
    }

    private func appendHistory(_ review: MojiWordReview, for id: MojiWordCardID) {
        var entries = history[id.key] ?? []
        entries.append(review)
        if entries.count > Self.historyLimit {
            entries.removeFirst(entries.count - Self.historyLimit)
        }
        history[id.key] = entries
    }

    private func manualReview(at now: Date, card: MojiWordCard, previous: MojiWordCard) -> MojiWordReview {
        MojiWordReview(
            at: now,
            button: nil,
            kind: .manual,
            interval: card.phase == .review ? card.interval : 0,
            lastInterval: Self.lastInterval(of: previous),
            easeFactor: card.easeFactor,
            seconds: 0
        )
    }

    private static func storedInterval(_ delay: MojiWordDelay) -> Int {
        switch delay {
        case .seconds(let seconds): -max(1, seconds)
        case .days(let days): max(1, days)
        }
    }

    private static func lastInterval(of card: MojiWordCard) -> Int {
        switch card.phase {
        case .new: 0
        case .learning, .relearning: card.phase == .relearning ? card.interval : 0
        case .review: card.interval
        }
    }

    private func forgottenCards(within span: Int, now: Date) -> [MojiWordCardID] {
        let context = context(at: now)
        let firstDay = context.today - max(1, span) + 1
        var found: [(id: MojiWordCardID, at: Date)] = []
        for (key, entries) in history {
            guard let id = MojiWordCardID(key: key),
                  catalog.word(id.wordID) != nil,
                  id.kind == .recognition || options.reverseCards,
                  cards[key]?.isSuspended != true else { continue }
            let lastAgain = entries.last { entry in
                entry.button == .again && entry.kind != .cram
                    && MojiWordDay.index(of: entry.at, startsAtHour: options.dayStartsAtHour, calendar: calendar) >= firstDay
            }
            if let lastAgain {
                found.append((id, lastAgain.at))
            }
        }
        return found
            .sorted { $0.at != $1.at ? $0.at > $1.at : $0.id < $1.id }
            .map(\.id)
    }

    private func resolveStep(now: Date) async -> MojiWordStudyStep {
        let step = nextStep(now: now)
        if case .finished = step {
            session = nil
            await flushHistory()
            await emit(now: now)
        }
        return step
    }

    private func nextStep(now: Date) -> MojiWordStudyStep {
        guard let state = session else {
            return .finished(makeSummary(now: now, isComplete: true))
        }
        let context = context(at: now)

        if state.scope.isCram {
            guard let id = state.pinned ?? state.cramQueue.first, let study = makeStudyCard(
                id,
                kind: queueKind(of: cards[id.key] ?? .fresh),
                counts: MojiWordQueueCounts(new: 0, learning: 0, review: state.cramQueue.count),
                context: context,
                isCram: true
            ) else {
                return .finished(makeSummary(now: now, isComplete: true))
            }
            return .card(study)
        }

        let queue = MojiWordQueue.build(
            scope: state.scope,
            catalog: catalog,
            cards: cards,
            day: days[context.today] ?? MojiWordDayStats(day: context.today),
            context: context
        )
        if let pinned = state.pinned,
           let study = makeStudyCard(
            pinned,
            kind: queueKind(of: cards[pinned.key] ?? .fresh),
            counts: queue.counts,
            context: context,
            isCram: false
           ) {
            return .card(study)
        }
        guard let entry = queue.next(at: now),
              let study = makeStudyCard(entry.id, kind: entry.kind, counts: queue.counts, context: context, isCram: false) else {
            return .finished(makeSummary(now: now, isComplete: true))
        }
        return .card(study)
    }

    private func makeSummary(now: Date, isComplete: Bool) -> MojiWordSessionSummary {
        let context = context(at: now)
        let queue = MojiWordQueue.build(
            scope: .deck,
            catalog: catalog,
            cards: cards,
            day: days[context.today] ?? MojiWordDayStats(day: context.today),
            context: context
        )
        let counters = session?.counters ?? MojiWordSessionCounters()
        return MojiWordSessionSummary(
            scope: session?.scope ?? .deck,
            answered: counters.answered,
            correct: counters.correct,
            again: counters.again,
            newCards: counters.newCards,
            seconds: counters.seconds,
            startedAt: session?.startedAt ?? now,
            finishedAt: now,
            learningLater: queue.laterToday,
            nextLearningAt: queue.learning.first { ($0.dueAt ?? .distantPast) > now }?.dueAt,
            leeches: counters.leeches,
            isComplete: isComplete,
            remaining: queue.counts
        )
    }

    private func makeStudyCard(
        _ id: MojiWordCardID,
        kind: MojiWordQueueKind,
        counts: MojiWordQueueCounts,
        context: MojiWordSchedulingContext,
        isCram: Bool
    ) -> MojiWordStudyCard? {
        guard let word = catalog.word(id.wordID) else { return nil }
        let card = cards[id.key] ?? .fresh
        return MojiWordStudyCard(
            id: id,
            word: word,
            card: card,
            kind: kind,
            sentenceIndex: card.reps,
            delays: isCram ? [:] : MojiWordScheduler.preview(card, id: id, context: context),
            counts: counts,
            isCram: isCram,
            canUndo: !(session?.undo.isEmpty ?? true),
            answered: session?.counters.answered ?? 0
        )
    }

    private func queueKind(of card: MojiWordCard) -> MojiWordQueueKind {
        switch card.phase {
        case .new: .new
        case .learning, .relearning: .learning
        case .review: .review
        }
    }

    private func context(at now: Date) -> MojiWordSchedulingContext {
        MojiWordSchedulingContext(options: options, now: now, calendar: calendar)
    }

    private func scheduleHistorySave() {
        historySave?.cancel()
        historySave = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await self?.flushHistory()
        }
    }

    private func flushHistory() async {
        historySave?.cancel()
        historySave = nil
        await resources.saveHistory(history)
    }

    private func ensureLoaded() async {
        if isLoaded { return }
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task {
            await self.load()
        }
        loadTask = task
        await task.value
    }

    private func load() async {
        let loader = catalogLoader
        catalog = await Task.detached(priority: .userInitiated) { loader() }.value
        let cache = await resources.load()
        cards = cache.cards
        history = cache.history
        days = cache.days
        options = cache.options.sanitized()
        notes = cache.notes
        isLoaded = true
        recomputeDerived(now: Date())
    }

    private func recomputeDerived(now: Date) {
        let context = context(at: now)
        clock = now
        today = context.today
        deckQueue = MojiWordQueue.build(
            scope: .deck,
            catalog: catalog,
            cards: cards,
            day: days[context.today] ?? MojiWordDayStats(day: context.today),
            context: context
        )
        sectionStats = MojiWordStats.sections(catalog: catalog, cards: cards, options: options, today: context.today)
        stateCounts = MojiWordStats.states(catalog: catalog, cards: cards, options: options, today: context.today)
        deckProgress = MojiWordStats.progress(catalog: catalog, cards: cards)
    }

    private func snapshot() -> MojiWordRepositorySnapshot {
        MojiWordRepositorySnapshot(
            isLoaded: isLoaded,
            catalog: catalog,
            cards: cards,
            options: options,
            notes: notes,
            days: days,
            today: today,
            clock: clock,
            queue: deckQueue.counts,
            nextLearningAt: deckQueue.learning.first { ($0.dueAt ?? .distantPast) > clock }?.dueAt,
            learningLater: deckQueue.laterToday,
            sections: sectionStats,
            states: stateCounts,
            progress: deckProgress,
            hasSession: session != nil
        )
    }

    private func emit(now: Date) async {
        recomputeDerived(now: now)
        guard let publish else { return }
        await publish(snapshot())
    }
}
