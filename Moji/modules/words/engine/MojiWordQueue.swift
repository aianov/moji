import Foundation

enum MojiWordScope: Hashable, Sendable {
    case deck
    case section(Int)
    case sectionOnly(Int)
    case reviewAhead(days: Int)
    case forgotten(days: Int)

    var isCram: Bool {
        if case .forgotten = self { return true }
        return false
    }

    var section: Int? {
        switch self {
        case .section(let number), .sectionOnly(let number): number
        case .deck, .reviewAhead, .forgotten: nil
        }
    }
}

enum MojiWordQueueKind: String, Equatable, Sendable {
    case new
    case learning
    case review
}

struct MojiWordQueueCounts: Equatable, Sendable {
    var new = 0
    var learning = 0
    var review = 0

    static let zero = MojiWordQueueCounts()

    var total: Int {
        new + learning + review
    }
}

struct MojiWordQueueEntry: Equatable, Sendable {
    let id: MojiWordCardID
    let kind: MojiWordQueueKind
    var dueAt: Date? = nil
}

struct MojiWordQueue: Equatable, Sendable {
    let learning: [MojiWordQueueEntry]
    let main: [MojiWordQueueEntry]
    let counts: MojiWordQueueCounts
    let laterToday: Int
    let nextLearningAt: Date?

    static let empty = MojiWordQueue(learning: [], main: [], counts: .zero, laterToday: 0, nextLearningAt: nil)

    func next(at now: Date, learnAheadSeconds: Int = MojiWordDefaults.learnAheadSeconds) -> MojiWordQueueEntry? {
        if let due = learning.first(where: { ($0.dueAt ?? .distantFuture) <= now }) {
            return due
        }
        if let first = main.first {
            return first
        }
        let horizon = now.addingTimeInterval(Double(learnAheadSeconds))
        return learning.first { ($0.dueAt ?? .distantFuture) <= horizon }
    }

    static func remainingLimits(
        options: MojiWordOptions,
        day: MojiWordDayStats
    ) -> (new: Int, review: Int) {
        let review = max(0, options.reviewsPerDay + day.extraReviews - day.reviewCards - day.newCards)
        let new = min(max(0, options.newPerDay + day.extraNew - day.newCards), review)
        return (new, review)
    }

    static func build(
        scope: MojiWordScope,
        catalog: MojiWordCatalog,
        cards: [String: MojiWordCard],
        day: MojiWordDayStats,
        context: MojiWordSchedulingContext
    ) -> MojiWordQueue {
        guard !scope.isCram else { return .empty }
        let options = context.options
        let today = context.today
        let cutoff = context.nextDayStartsAt
        let kinds: [MojiWordCardKind] = options.reverseCards ? [.recognition, .recall] : [.recognition]

        var learning: [MojiWordQueueEntry] = []
        var dueCandidates: [(entry: MojiWordQueueEntry, card: MojiWordCard, position: Int)] = []
        var newCandidates: [(id: MojiWordCardID, order: Int)] = []

        for (position, word) in catalog.words.enumerated() {
            let dueInScope: Bool
            let newInScope: Bool
            switch scope {
            case .deck:
                dueInScope = true
                newInScope = true
            case .section(let number):
                dueInScope = true
                newInScope = word.section == number
            case .sectionOnly(let number):
                dueInScope = word.section == number
                newInScope = dueInScope
            case .reviewAhead:
                dueInScope = true
                newInScope = false
            case .forgotten:
                dueInScope = false
                newInScope = false
            }
            guard dueInScope || newInScope else { continue }

            for kind in kinds {
                let id = MojiWordCardID(wordID: word.id, kind: kind)
                let card = cards[id.key] ?? .fresh
                guard !card.isSuspended, !card.isBuried(on: today) else { continue }

                if card.isIntradayLearning, let dueAt = card.dueAt {
                    if dueInScope, dueAt < cutoff {
                        learning.append(MojiWordQueueEntry(id: id, kind: .learning, dueAt: dueAt))
                    }
                    continue
                }

                if options.burySiblings, options.reverseCards,
                   let sibling = cards[id.sibling.key], sibling.lastAnsweredDay == today {
                    continue
                }

                switch card.phase {
                case .new:
                    guard newInScope else { continue }
                    let order = options.newOrder == .random ? (catalog.shuffledPosition(of: word.id) ?? position) : position
                    newCandidates.append((id, order))
                case .learning, .relearning:
                    guard dueInScope, let dueDay = card.dueDay, dueDay <= today else { continue }
                    dueCandidates.append((MojiWordQueueEntry(id: id, kind: .learning), card, position))
                case .review:
                    guard dueInScope, let dueDay = card.dueDay else { continue }
                    let horizon: Int
                    if case .reviewAhead(let days) = scope {
                        horizon = today + max(0, days)
                    } else {
                        horizon = today
                    }
                    guard dueDay <= horizon else { continue }
                    dueCandidates.append((MojiWordQueueEntry(id: id, kind: .review), card, position))
                }
            }
        }

        learning.sort { lhs, rhs in
            let left = lhs.dueAt ?? .distantFuture
            let right = rhs.dueAt ?? .distantFuture
            return left != right ? left < right : lhs.id < rhs.id
        }
        let nextLearningAt = learning.first?.dueAt
        let laterToday = learning.filter { ($0.dueAt ?? .distantFuture) > context.now }.count

        let limits: (new: Int, review: Int)
        if case .reviewAhead = scope {
            limits = (0, Int.max)
        } else {
            limits = remainingLimits(options: options, day: day)
        }

        let sortedDue = sortDue(dueCandidates, order: options.reviewOrder, today: today)
        var gathered: Set<String> = []
        var reviews: [MojiWordQueueEntry] = []
        for entry in sortedDue where reviews.count < limits.review {
            if options.burySiblings, options.reverseCards, gathered.contains(entry.id.wordID) {
                continue
            }
            gathered.insert(entry.id.wordID)
            reviews.append(entry)
        }

        let newRoom = min(limits.new, max(0, limits.review - reviews.count))
        var fresh: [(id: MojiWordCardID, order: Int)] = []
        if newRoom > 0 {
            let ordered = newCandidates.sorted { lhs, rhs in
                lhs.order != rhs.order ? lhs.order < rhs.order : lhs.id.kind.rawValue < rhs.id.kind.rawValue
            }
            for candidate in ordered where fresh.count < newRoom {
                if options.burySiblings, options.reverseCards, gathered.contains(candidate.id.wordID) {
                    continue
                }
                gathered.insert(candidate.id.wordID)
                fresh.append(candidate)
            }
        }
        let newEntries = fresh
            .enumerated()
            .sorted { lhs, rhs in
                let left = lhs.element.id.kind == .recognition ? 0 : 1
                let right = rhs.element.id.kind == .recognition ? 0 : 1
                return left != right ? left < right : lhs.offset < rhs.offset
            }
            .map { MojiWordQueueEntry(id: $0.element.id, kind: .new) }

        let main: [MojiWordQueueEntry]
        switch options.newReviewMix {
        case .mix:
            main = intersperse(reviews, newEntries)
        case .newFirst:
            main = newEntries + reviews
        case .reviewsFirst:
            main = reviews + newEntries
        }

        let counts = MojiWordQueueCounts(
            new: newEntries.count,
            learning: learning.count + reviews.filter { $0.kind == .learning }.count,
            review: reviews.filter { $0.kind == .review }.count
        )
        return MojiWordQueue(
            learning: learning,
            main: main,
            counts: counts,
            laterToday: laterToday,
            nextLearningAt: nextLearningAt
        )
    }

    static func intersperse(_ reviews: [MojiWordQueueEntry], _ new: [MojiWordQueueEntry]) -> [MojiWordQueueEntry] {
        guard !new.isEmpty else { return reviews }
        guard !reviews.isEmpty else { return new }
        let ratio = Double(reviews.count + 1) / Double(new.count + 1)
        var result: [MojiWordQueueEntry] = []
        result.reserveCapacity(reviews.count + new.count)
        var reviewIndex = 0
        var newIndex = 0
        while reviewIndex < reviews.count || newIndex < new.count {
            let takesNew = newIndex < new.count
                && (reviewIndex >= reviews.count || Double(newIndex + 1) * ratio <= Double(reviewIndex + 1))
            if takesNew {
                result.append(new[newIndex])
                newIndex += 1
            } else {
                result.append(reviews[reviewIndex])
                reviewIndex += 1
            }
        }
        return result
    }

    private static func sortDue(
        _ candidates: [(entry: MojiWordQueueEntry, card: MojiWordCard, position: Int)],
        order: MojiWordReviewOrder,
        today: Int
    ) -> [MojiWordQueueEntry] {
        candidates
            .map { candidate in
                (
                    entry: candidate.entry,
                    due: candidate.card.dueDay ?? today,
                    interval: candidate.card.interval,
                    position: candidate.position,
                    shuffle: MojiWordFuzz.dailyOrder(for: candidate.entry.id, day: today)
                )
            }
            .sorted { lhs, rhs in
                switch order {
                case .dueThenRandom:
                    if lhs.due != rhs.due { return lhs.due < rhs.due }
                case .dueThenFrequency:
                    if lhs.due != rhs.due { return lhs.due < rhs.due }
                    if lhs.position != rhs.position { return lhs.position < rhs.position }
                case .ascendingIntervals:
                    if lhs.interval != rhs.interval { return lhs.interval < rhs.interval }
                case .descendingIntervals:
                    if lhs.interval != rhs.interval { return lhs.interval > rhs.interval }
                case .random:
                    break
                }
                if lhs.shuffle != rhs.shuffle { return lhs.shuffle < rhs.shuffle }
                return lhs.entry.id < rhs.entry.id
            }
            .map(\.entry)
    }
}
