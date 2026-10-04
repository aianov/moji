import Foundation

enum MojiWordCardState: String, CaseIterable, Sendable {
    case new
    case learning
    case relearning
    case young
    case mature
    case suspended
    case buried

    static func of(_ card: MojiWordCard, today: Int) -> MojiWordCardState {
        if card.isSuspended { return .suspended }
        if card.isBuried(on: today) { return .buried }
        switch card.phase {
        case .new: return .new
        case .learning: return .learning
        case .relearning: return .relearning
        case .review: return card.isMature ? .mature : .young
        }
    }
}

struct MojiWordStateCounts: Equatable, Sendable {
    var new = 0
    var learning = 0
    var relearning = 0
    var young = 0
    var mature = 0
    var suspended = 0
    var buried = 0
    var leeches = 0
    var flagged = 0

    static let zero = MojiWordStateCounts()

    var total: Int {
        new + learning + relearning + young + mature + suspended + buried
    }

    func count(_ state: MojiWordCardState) -> Int {
        switch state {
        case .new: new
        case .learning: learning
        case .relearning: relearning
        case .young: young
        case .mature: mature
        case .suspended: suspended
        case .buried: buried
        }
    }

    mutating func add(_ state: MojiWordCardState) {
        switch state {
        case .new: new += 1
        case .learning: learning += 1
        case .relearning: relearning += 1
        case .young: young += 1
        case .mature: mature += 1
        case .suspended: suspended += 1
        case .buried: buried += 1
        }
    }
}

struct MojiWordSectionStats: Equatable, Sendable {
    let number: Int
    var words = 0
    var cards = 0
    var states = MojiWordStateCounts.zero
    var due = 0

    var seen: Int {
        cards - states.new
    }

    var seenFraction: Double {
        cards > 0 ? Double(seen) / Double(cards) : 0
    }

    var matureFraction: Double {
        cards > 0 ? Double(states.mature) / Double(cards) : 0
    }

    var isKnown: Bool {
        cards > 0 && states.mature == cards
    }

    var isUntouched: Bool {
        cards > 0 && states.new == cards
    }
}

struct MojiWordDeckProgress: Equatable, Sendable {
    var words = 0
    var seenWords = 0
    var youngWords = 0
    var matureWords = 0
    var leeches = 0

    static let zero = MojiWordDeckProgress()
}

struct MojiWordRetention: Equatable, Sendable {
    var youngPassed = 0
    var youngFailed = 0
    var maturePassed = 0
    var matureFailed = 0

    var young: Double? {
        rate(youngPassed, youngFailed)
    }

    var mature: Double? {
        rate(maturePassed, matureFailed)
    }

    var total: Double? {
        rate(youngPassed + maturePassed, youngFailed + matureFailed)
    }

    var reviews: Int {
        youngPassed + youngFailed + maturePassed + matureFailed
    }

    private func rate(_ passed: Int, _ failed: Int) -> Double? {
        let all = passed + failed
        return all > 0 ? Double(passed) / Double(all) : nil
    }
}

enum MojiWordStats {
    static func cardIDs(of word: MojiWord, options: MojiWordOptions) -> [MojiWordCardID] {
        options.reverseCards
            ? [MojiWordCardID(wordID: word.id, kind: .recognition), MojiWordCardID(wordID: word.id, kind: .recall)]
            : [MojiWordCardID(wordID: word.id, kind: .recognition)]
    }

    static func states(
        catalog: MojiWordCatalog,
        cards: [String: MojiWordCard],
        options: MojiWordOptions,
        today: Int
    ) -> MojiWordStateCounts {
        var counts = MojiWordStateCounts.zero
        for word in catalog.words {
            for id in cardIDs(of: word, options: options) {
                let card = cards[id.key] ?? .fresh
                counts.add(.of(card, today: today))
                if card.isLeech { counts.leeches += 1 }
                if card.flag != nil { counts.flagged += 1 }
            }
        }
        return counts
    }

    static func sections(
        catalog: MojiWordCatalog,
        cards: [String: MojiWordCard],
        options: MojiWordOptions,
        today: Int
    ) -> [Int: MojiWordSectionStats] {
        var result: [Int: MojiWordSectionStats] = [:]
        for section in catalog.sections {
            var stats = MojiWordSectionStats(number: section.number)
            for wordID in section.wordIDs {
                guard let word = catalog.word(wordID) else { continue }
                stats.words += 1
                for id in cardIDs(of: word, options: options) {
                    let card = cards[id.key] ?? .fresh
                    stats.cards += 1
                    stats.states.add(.of(card, today: today))
                    if card.isLeech { stats.states.leeches += 1 }
                    if card.flag != nil { stats.states.flagged += 1 }
                    if isDue(card, today: today) { stats.due += 1 }
                }
            }
            result[section.number] = stats
        }
        return result
    }

    static func progress(
        catalog: MojiWordCatalog,
        cards: [String: MojiWordCard]
    ) -> MojiWordDeckProgress {
        var progress = MojiWordDeckProgress.zero
        for word in catalog.words {
            progress.words += 1
            let card = cards[MojiWordCardID(wordID: word.id).key] ?? .fresh
            if !card.isNew { progress.seenWords += 1 }
            if card.isMature { progress.matureWords += 1 }
            if card.isYoung || card.isInLearning { progress.youngWords += 1 }
            if card.isLeech { progress.leeches += 1 }
        }
        return progress
    }

    static func isDue(_ card: MojiWordCard, today: Int) -> Bool {
        guard !card.isSuspended, !card.isBuried(on: today) else { return false }
        if card.isIntradayLearning { return true }
        guard card.phase != .new, let dueDay = card.dueDay else { return false }
        return dueDay <= today
    }

    static func forecast(
        catalog: MojiWordCatalog,
        cards: [String: MojiWordCard],
        options: MojiWordOptions,
        today: Int,
        days: Int
    ) -> [Int] {
        var counts = Array(repeating: 0, count: max(1, days))
        for word in catalog.words {
            for id in cardIDs(of: word, options: options) {
                guard let card = cards[id.key], !card.isSuspended, card.phase != .new else { continue }
                let offset: Int
                if card.isIntradayLearning {
                    offset = 0
                } else if let dueDay = card.dueDay {
                    offset = max(0, dueDay - today)
                } else {
                    continue
                }
                if offset < counts.count {
                    counts[offset] += 1
                }
            }
        }
        return counts
    }

    static func retention(_ days: [Int: MojiWordDayStats], from first: Int, through last: Int) -> MojiWordRetention {
        var retention = MojiWordRetention()
        for (day, stats) in days where day >= first && day <= last {
            retention.youngPassed += stats.youngPassed
            retention.youngFailed += stats.youngFailed
            retention.maturePassed += stats.maturePassed
            retention.matureFailed += stats.matureFailed
        }
        return retention
    }

    static func answers(_ days: [Int: MojiWordDayStats], from first: Int, through last: Int) -> [MojiWordDayStats] {
        (first...max(first, last)).map { days[$0] ?? MojiWordDayStats(day: $0) }
    }

    static func seconds(_ days: [Int: MojiWordDayStats], from first: Int, through last: Int) -> Double {
        days.reduce(0) { total, entry in
            entry.key >= first && entry.key <= last ? total + entry.value.seconds : total
        }
    }

    static func studyStreak(_ days: [Int: MojiWordDayStats], today: Int) -> Int {
        var cursor = today
        if (days[cursor]?.answers ?? 0) == 0 {
            cursor -= 1
        }
        var streak = 0
        while (days[cursor]?.answers ?? 0) > 0 {
            streak += 1
            cursor -= 1
        }
        return streak
    }
}
