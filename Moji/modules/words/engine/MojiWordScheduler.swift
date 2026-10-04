import Foundation

struct MojiWordSteps: Equatable, Sendable {
    let seconds: [Int]

    init(minutes: [Double]) {
        seconds = minutes.map { max(1, Int(($0 * 60).rounded())) }
    }

    var count: Int {
        seconds.count
    }

    var remainingForFailed: Int {
        max(1, count)
    }

    func index(remaining: Int) -> Int {
        let total = count
        return min(max(0, total - remaining % 1_000), max(0, total - 1))
    }

    func delay(at index: Int) -> Int? {
        seconds.indices.contains(index) ? seconds[index] : nil
    }

    var againDelay: Int? {
        delay(at: 0)
    }

    func hardDelay(remaining: Int) -> Int? {
        let index = index(remaining: remaining)
        guard let current = delay(at: index) else { return nil }
        guard index == 0 else { return current }
        if let next = delay(at: 1) {
            return (current + next) / 2
        }
        return min(current * 3 / 2, current + MojiWordScheduler.secondsPerDay)
    }

    func goodDelay(remaining: Int) -> Int? {
        delay(at: index(remaining: remaining) + 1)
    }

    func remainingForGood(remaining: Int) -> Int {
        max(0, count - (index(remaining: remaining) + 1))
    }
}

struct MojiWordSchedulingContext: Sendable {
    let options: MojiWordOptions
    let today: Int
    let now: Date
    let nextDayStartsAt: Date

    init(options: MojiWordOptions, now: Date, calendar: Calendar) {
        self.options = options
        self.now = now
        let today = MojiWordDay.index(of: now, startsAtHour: options.dayStartsAtHour, calendar: calendar)
        self.today = today
        self.nextDayStartsAt = MojiWordDay.start(of: today + 1, startsAtHour: options.dayStartsAtHour, calendar: calendar)
    }

    init(options: MojiWordOptions, today: Int, now: Date, nextDayStartsAt: Date) {
        self.options = options
        self.today = today
        self.now = now
        self.nextDayStartsAt = nextDayStartsAt
    }

    var learningSteps: MojiWordSteps {
        MojiWordSteps(minutes: options.learningSteps)
    }

    var relearningSteps: MojiWordSteps {
        MojiWordSteps(minutes: options.relearningSteps)
    }

    var startingEaseFactor: Int {
        Int((options.startingEase * 1_000).rounded())
    }

    var secondsUntilNextDay: Int {
        max(0, Int(nextDayStartsAt.timeIntervalSince(now).rounded(.down)))
    }
}

struct MojiWordOutcome: Equatable, Sendable {
    var card: MojiWordCard
    var delay: MojiWordDelay
    var becameLeech = false
}

enum MojiWordScheduler {
    static let secondsPerDay = 86_400
    static let minimumEaseFactor = 1_300
    static let againEaseDelta = -200
    static let hardEaseDelta = -150
    static let easyEaseDelta = 150
    static let matureInterval = 21
    static let learningFuzzShare = 0.25
    static let learningFuzzCapSeconds = 300.0
    static let knownIntervalRange = 21...60
    static let fuzzRanges: [(start: Double, end: Double, factor: Double)] = [
        (2.5, 7.0, 0.15),
        (7.0, 20.0, 0.1),
        (20.0, .greatestFiniteMagnitude, 0.05)
    ]

    static func preview(
        _ card: MojiWordCard,
        id: MojiWordCardID,
        context: MojiWordSchedulingContext
    ) -> [MojiWordButton: MojiWordDelay] {
        var delays: [MojiWordButton: MojiWordDelay] = [:]
        for button in MojiWordButton.allCases {
            delays[button] = answer(card, id: id, button: button, context: context).delay
        }
        return delays
    }

    static func answer(
        _ card: MojiWordCard,
        id: MojiWordCardID,
        button: MojiWordButton,
        context: MojiWordSchedulingContext,
        learningFuzz: Double = 0
    ) -> MojiWordOutcome {
        let fuzz = MojiWordFuzz.factor(for: id, reps: card.reps)
        var outcome: MojiWordOutcome
        switch card.phase {
        case .new:
            var learning = card
            learning.phase = .learning
            learning.remainingSteps = context.learningSteps.remainingForFailed
            outcome = answerLearning(learning, button: button, context: context, fuzz: fuzz)
        case .learning:
            outcome = answerLearning(card, button: button, context: context, fuzz: fuzz)
        case .review:
            outcome = answerReview(card, button: button, context: context, fuzz: fuzz)
        case .relearning:
            outcome = answerRelearning(card, button: button, context: context)
        }

        if case .seconds(let seconds) = outcome.delay, seconds >= context.secondsUntilNextDay {
            outcome.delay = .days((seconds - context.secondsUntilNextDay) / secondsPerDay + 1)
        }

        outcome.card.reps = card.reps + 1
        outcome.card.lastAnsweredDay = context.today
        outcome.card.buriedUntil = nil
        if card.phase == .new {
            outcome.card.introducedDay = context.today
        }
        switch outcome.delay {
        case .seconds(let seconds):
            let fuzzed = seconds + learningFuzzSeconds(seconds, fraction: learningFuzz)
            outcome.card.dueAt = context.now.addingTimeInterval(Double(fuzzed))
            outcome.card.dueDay = nil
        case .days(let days):
            outcome.card.dueAt = nil
            outcome.card.dueDay = context.today + days
        }
        return outcome
    }

    static func reviewKind(of card: MojiWordCard) -> MojiWordReviewKind {
        switch card.phase {
        case .new, .learning: .learn
        case .review: .review
        case .relearning: .relearn
        }
    }

    static func leechThresholdMet(lapses: Int, threshold: Int) -> Bool {
        guard threshold > 0 else { return false }
        let half = max(1, Int((Double(threshold) / 2).rounded(.up)))
        return lapses >= threshold && (lapses - threshold) % half == 0
    }

    static func learningFuzzSeconds(_ seconds: Int, fraction: Double) -> Int {
        let room = Int(min(Double(seconds) * learningFuzzShare, learningFuzzCapSeconds).rounded(.down))
        guard room > 0 else { return 0 }
        return Int((Double(room) * min(max(fraction, 0), 0.999_999)).rounded(.down))
    }

    static func fuzzDelta(_ interval: Double) -> Double {
        guard interval >= 2.5 else { return 0 }
        return fuzzRanges.reduce(1.0) { delta, range in
            delta + range.factor * max(0, min(interval, range.end) - range.start)
        }
    }

    static func fuzzBounds(_ interval: Double, minimum: Int, maximum: Int) -> ClosedRange<Int> {
        let minimum = min(minimum, maximum)
        let clamped = min(Double(maximum), max(Double(minimum), interval))
        let delta = fuzzDelta(clamped)
        var lower = Int((clamped - delta).rounded())
        var upper = Int((clamped + delta).rounded())
        lower = min(maximum, max(minimum, lower))
        upper = min(maximum, max(minimum, upper))
        if upper == lower, upper > 2, upper < maximum {
            upper = lower + 1
        }
        return lower...max(lower, upper)
    }

    static func withFuzz(_ interval: Double, minimum: Int, maximum: Int, factor: Double?) -> Int {
        guard let factor else {
            let rounded = interval.isFinite ? Int(interval.rounded()) : maximum
            return min(maximum, max(min(minimum, maximum), rounded))
        }
        let bounds = fuzzBounds(interval, minimum: minimum, maximum: maximum)
        let span = Double(bounds.upperBound - bounds.lowerBound + 1)
        return bounds.lowerBound + Int((min(max(factor, 0), 0.999_999) * span).rounded(.down))
    }

    static func knownCard(
        _ card: MojiWordCard,
        id: MojiWordCardID,
        context: MojiWordSchedulingContext
    ) -> MojiWordCard {
        let range = knownIntervalRange
        let spread = MojiWordFuzz.unit(MojiWordFuzz.stableHash(id.key) ^ 0x5EED)
        let interval = min(
            context.options.maximumInterval,
            range.lowerBound + Int((spread * Double(range.count)).rounded(.down))
        )
        var next = card
        next.phase = .review
        next.remainingSteps = 0
        next.interval = max(1, interval)
        next.dueDay = context.today + next.interval
        next.dueAt = nil
        next.easeFactor = card.easeFactor > 0 ? card.easeFactor : context.startingEaseFactor
        next.isSuspended = false
        next.buriedUntil = nil
        if next.introducedDay == nil {
            next.introducedDay = context.today
        }
        return next
    }

    static func rescheduled(
        _ card: MojiWordCard,
        inDays days: Int,
        context: MojiWordSchedulingContext
    ) -> MojiWordCard {
        var next = card
        let days = max(0, days)
        switch card.phase {
        case .review:
            next.dueDay = context.today + days
        case .new, .learning, .relearning:
            next.phase = .review
            next.remainingSteps = 0
            next.interval = min(context.options.maximumInterval, max(1, days))
            next.dueDay = context.today + days
            if next.easeFactor == 0 {
                next.easeFactor = context.startingEaseFactor
            }
            if next.introducedDay == nil {
                next.introducedDay = context.today
            }
        }
        next.dueAt = nil
        next.buriedUntil = nil
        return next
    }

    static func forgotten(_ card: MojiWordCard) -> MojiWordCard {
        var next = MojiWordCard.fresh
        next.flag = card.flag
        return next
    }

    private static func answerLearning(
        _ card: MojiWordCard,
        button: MojiWordButton,
        context: MojiWordSchedulingContext,
        fuzz: Double
    ) -> MojiWordOutcome {
        let steps = context.learningSteps
        switch button {
        case .again:
            if let delay = steps.againDelay {
                return stepping(card, phase: .learning, remaining: steps.remainingForFailed, seconds: delay)
            }
        case .hard:
            if let delay = steps.hardDelay(remaining: card.remainingSteps) {
                return stepping(card, phase: .learning, remaining: card.remainingSteps, seconds: delay)
            }
        case .good:
            if let delay = steps.goodDelay(remaining: card.remainingSteps) {
                return stepping(
                    card,
                    phase: .learning,
                    remaining: steps.remainingForGood(remaining: card.remainingSteps),
                    seconds: delay
                )
            }
        case .easy:
            break
        }
        return graduate(card, easy: button == .easy, context: context, fuzz: fuzz)
    }

    private static func graduate(
        _ card: MojiWordCard,
        easy: Bool,
        context: MojiWordSchedulingContext,
        fuzz: Double
    ) -> MojiWordOutcome {
        let (minimum, maximum) = bounds(1, context: context)
        let good = withFuzz(Double(context.options.graduatingInterval), minimum: minimum, maximum: maximum, factor: fuzz)
        var interval = good
        if easy {
            interval = withFuzz(Double(context.options.easyInterval), minimum: good + 1, maximum: maximum, factor: fuzz)
        }
        var next = card
        next.phase = .review
        next.remainingSteps = 0
        next.interval = interval
        next.easeFactor = context.startingEaseFactor
        return MojiWordOutcome(card: next, delay: .days(interval))
    }

    private static func answerReview(
        _ card: MojiWordCard,
        button: MojiWordButton,
        context: MojiWordSchedulingContext,
        fuzz: Double
    ) -> MojiWordOutcome {
        let scheduled = max(1, card.interval)
        let lastReviewDay = (card.dueDay ?? context.today) - scheduled
        let daysLate = (context.today - lastReviewDay) - scheduled
        let easeFactor = card.easeFactor > 0 ? card.easeFactor : context.startingEaseFactor
        let ease = Double(easeFactor) / 1_000
        var next = card
        next.easeFactor = easeFactor
        next.remainingSteps = 0

        if button == .again {
            next.lapses = card.lapses + 1
            next.easeFactor = max(minimumEaseFactor, easeFactor + againEaseDelta)
            let (minimum, maximum) = bounds(context.options.minimumInterval, context: context)
            let failing = min(maximum, max(minimum, Int(Double(scheduled) * context.options.newInterval)))
            next.interval = failing
            let becameLeech = leechThresholdMet(lapses: next.lapses, threshold: context.options.leechThreshold)
            if becameLeech {
                next.isLeech = true
                if context.options.leechAction == .suspend {
                    next.isSuspended = true
                }
            }
            if let delay = context.relearningSteps.againDelay {
                next.phase = .relearning
                next.remainingSteps = context.relearningSteps.remainingForFailed
                return MojiWordOutcome(card: next, delay: .seconds(delay), becameLeech: becameLeech)
            }
            next.phase = .review
            return MojiWordOutcome(card: next, delay: .days(failing), becameLeech: becameLeech)
        }

        let intervals = daysLate < 0
            ? earlyIntervals(scheduled: scheduled, daysLate: daysLate, ease: ease, context: context)
            : passingIntervals(scheduled: scheduled, daysLate: daysLate, ease: ease, context: context, fuzz: fuzz)
        next.phase = .review
        switch button {
        case .again:
            break
        case .hard:
            next.interval = intervals.hard
            next.easeFactor = max(minimumEaseFactor, easeFactor + hardEaseDelta)
        case .good:
            next.interval = intervals.good
        case .easy:
            next.interval = intervals.easy
            next.easeFactor = easeFactor + easyEaseDelta
        }
        return MojiWordOutcome(card: next, delay: .days(next.interval))
    }

    static func passingIntervals(
        scheduled: Int,
        daysLate: Int,
        ease: Double,
        context: MojiWordSchedulingContext,
        fuzz: Double?
    ) -> (hard: Int, good: Int, easy: Int) {
        let current = Double(scheduled)
        let late = Double(max(0, daysLate))
        let hardFactor = context.options.hardInterval
        let hardMinimum = hardFactor <= 1 ? 0 : scheduled + 1
        let hard = constrain(current * hardFactor, minimum: hardMinimum, context: context, fuzz: fuzz)
        let goodMinimum = hardFactor <= 1 ? scheduled + 1 : hard + 1
        let good = constrain((current + late / 2) * ease, minimum: goodMinimum, context: context, fuzz: fuzz)
        let easy = constrain(
            (current + late) * ease * context.options.easyBonus,
            minimum: good + 1,
            context: context,
            fuzz: fuzz
        )
        return (hard, good, easy)
    }

    static func earlyIntervals(
        scheduled: Int,
        daysLate: Int,
        ease: Double,
        context: MojiWordSchedulingContext
    ) -> (hard: Int, good: Int, easy: Int) {
        let planned = Double(scheduled)
        let elapsed = planned + Double(daysLate)
        let hardFactor = context.options.hardInterval
        let hard = constrain(
            max(elapsed * hardFactor, planned * hardFactor / 2),
            minimum: 0,
            context: context,
            fuzz: nil
        )
        let good = constrain(max(elapsed * ease, planned), minimum: 0, context: context, fuzz: nil)
        let bonus = context.options.easyBonus
        let reducedBonus = bonus - (bonus - 1) / 2
        let easy = constrain(max(elapsed * ease, planned) * reducedBonus, minimum: 0, context: context, fuzz: nil)
        return (hard, good, easy)
    }

    private static func answerRelearning(
        _ card: MojiWordCard,
        button: MojiWordButton,
        context: MojiWordSchedulingContext
    ) -> MojiWordOutcome {
        let steps = context.relearningSteps
        let maximum = max(1, context.options.maximumInterval)
        var next = card
        switch button {
        case .again:
            if let delay = steps.againDelay {
                return stepping(card, phase: .relearning, remaining: steps.remainingForFailed, seconds: delay)
            }
        case .hard:
            if let delay = steps.hardDelay(remaining: card.remainingSteps) {
                return stepping(card, phase: .relearning, remaining: card.remainingSteps, seconds: delay)
            }
        case .good:
            if let delay = steps.goodDelay(remaining: card.remainingSteps) {
                return stepping(
                    card,
                    phase: .relearning,
                    remaining: steps.remainingForGood(remaining: card.remainingSteps),
                    seconds: delay
                )
            }
        case .easy:
            next.interval = min(maximum, max(1, card.interval) + 1)
        }
        next.phase = .review
        next.remainingSteps = 0
        next.interval = min(maximum, max(1, next.interval))
        return MojiWordOutcome(card: next, delay: .days(next.interval))
    }

    private static func stepping(
        _ card: MojiWordCard,
        phase: MojiWordPhase,
        remaining: Int,
        seconds: Int
    ) -> MojiWordOutcome {
        var next = card
        next.phase = phase
        next.remainingSteps = remaining
        return MojiWordOutcome(card: next, delay: .seconds(seconds))
    }

    private static func constrain(
        _ interval: Double,
        minimum: Int,
        context: MojiWordSchedulingContext,
        fuzz: Double?
    ) -> Int {
        let (low, high) = bounds(minimum, context: context)
        return withFuzz(interval * context.options.intervalModifier, minimum: low, maximum: high, factor: fuzz)
    }

    private static func bounds(_ minimum: Int, context: MojiWordSchedulingContext) -> (Int, Int) {
        let maximum = max(1, context.options.maximumInterval)
        return (min(max(1, minimum), maximum), maximum)
    }
}
