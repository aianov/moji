import Foundation

enum MojiWordCardKind: String, Codable, CaseIterable, Sendable {
    case recognition = "f"
    case recall = "r"
}

struct MojiWordCardID: Hashable, Comparable, Sendable {
    let wordID: String
    let kind: MojiWordCardKind

    private static let recallSuffix = "~r"

    init(wordID: String, kind: MojiWordCardKind = .recognition) {
        self.wordID = wordID
        self.kind = kind
    }

    init?(key: String) {
        if key.hasSuffix(Self.recallSuffix) {
            wordID = String(key.dropLast(Self.recallSuffix.count))
            kind = .recall
        } else {
            wordID = key
            kind = .recognition
        }
        guard !wordID.isEmpty else { return nil }
    }

    var key: String {
        kind == .recognition ? wordID : wordID + Self.recallSuffix
    }

    var sibling: MojiWordCardID {
        MojiWordCardID(wordID: wordID, kind: kind == .recognition ? .recall : .recognition)
    }

    static func < (lhs: MojiWordCardID, rhs: MojiWordCardID) -> Bool {
        lhs.key < rhs.key
    }
}

enum MojiWordPhase: String, Codable, CaseIterable, Sendable {
    case new
    case learning
    case review
    case relearning
}

enum MojiWordFlag: Int, Codable, CaseIterable, Identifiable, Sendable {
    case red = 1
    case orange
    case green
    case blue
    case pink
    case turquoise
    case purple

    var id: Int { rawValue }
}

enum MojiWordButton: Int, Codable, CaseIterable, Identifiable, Sendable {
    case again = 1
    case hard
    case good
    case easy

    var id: Int { rawValue }

    var isPass: Bool {
        self != .again
    }
}

enum MojiWordReviewKind: Int, Codable, Sendable {
    case learn = 0
    case review = 1
    case relearn = 2
    case cram = 3
    case manual = 4
}

enum MojiWordDelay: Hashable, Sendable {
    case seconds(Int)
    case days(Int)
}

struct MojiWordCard: Codable, Equatable, Sendable {
    var phase: MojiWordPhase = .new
    var remainingSteps = 0
    var dueAt: Date? = nil
    var dueDay: Int? = nil
    var interval = 0
    var easeFactor = 0
    var reps = 0
    var lapses = 0
    var isSuspended = false
    var buriedUntil: Int? = nil
    var flag: MojiWordFlag? = nil
    var isLeech = false
    var lastAnsweredDay: Int? = nil
    var introducedDay: Int? = nil

    static let fresh = MojiWordCard()

    enum CodingKeys: String, CodingKey {
        case phase = "p"
        case remainingSteps = "s"
        case dueAt = "da"
        case dueDay = "dd"
        case interval = "i"
        case easeFactor = "e"
        case reps = "n"
        case lapses = "l"
        case isSuspended = "su"
        case buriedUntil = "b"
        case flag = "f"
        case isLeech = "lc"
        case lastAnsweredDay = "la"
        case introducedDay = "in"
    }

    init() {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawPhase = try container.decode(String.self, forKey: .phase)
        guard let phase = MojiWordPhase(rawValue: rawPhase) else {
            throw DecodingError.dataCorruptedError(forKey: .phase, in: container, debugDescription: "Unknown phase \(rawPhase)")
        }
        self.phase = phase
        remainingSteps = (try? container.decodeIfPresent(Int.self, forKey: .remainingSteps)) ?? 0
        dueAt = try? container.decodeIfPresent(Date.self, forKey: .dueAt)
        dueDay = try? container.decodeIfPresent(Int.self, forKey: .dueDay)
        interval = (try? container.decodeIfPresent(Int.self, forKey: .interval)) ?? 0
        easeFactor = (try? container.decodeIfPresent(Int.self, forKey: .easeFactor)) ?? 0
        reps = (try? container.decodeIfPresent(Int.self, forKey: .reps)) ?? 0
        lapses = (try? container.decodeIfPresent(Int.self, forKey: .lapses)) ?? 0
        isSuspended = (try? container.decodeIfPresent(Bool.self, forKey: .isSuspended)) ?? false
        buriedUntil = try? container.decodeIfPresent(Int.self, forKey: .buriedUntil)
        flag = (try? container.decodeIfPresent(Int.self, forKey: .flag)).flatMap(MojiWordFlag.init(rawValue:))
        isLeech = (try? container.decodeIfPresent(Bool.self, forKey: .isLeech)) ?? false
        lastAnsweredDay = try? container.decodeIfPresent(Int.self, forKey: .lastAnsweredDay)
        introducedDay = try? container.decodeIfPresent(Int.self, forKey: .introducedDay)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phase.rawValue, forKey: .phase)
        if remainingSteps != 0 { try container.encode(remainingSteps, forKey: .remainingSteps) }
        try container.encodeIfPresent(dueAt, forKey: .dueAt)
        try container.encodeIfPresent(dueDay, forKey: .dueDay)
        if interval != 0 { try container.encode(interval, forKey: .interval) }
        if easeFactor != 0 { try container.encode(easeFactor, forKey: .easeFactor) }
        if reps != 0 { try container.encode(reps, forKey: .reps) }
        if lapses != 0 { try container.encode(lapses, forKey: .lapses) }
        if isSuspended { try container.encode(true, forKey: .isSuspended) }
        try container.encodeIfPresent(buriedUntil, forKey: .buriedUntil)
        try container.encodeIfPresent(flag?.rawValue, forKey: .flag)
        if isLeech { try container.encode(true, forKey: .isLeech) }
        try container.encodeIfPresent(lastAnsweredDay, forKey: .lastAnsweredDay)
        try container.encodeIfPresent(introducedDay, forKey: .introducedDay)
    }

    var ease: Double {
        Double(easeFactor) / 1000
    }

    var isNew: Bool {
        phase == .new
    }

    var isInLearning: Bool {
        phase == .learning || phase == .relearning
    }

    var isIntradayLearning: Bool {
        isInLearning && dueAt != nil
    }

    var isMature: Bool {
        phase == .review && interval >= MojiWordScheduler.matureInterval
    }

    var isYoung: Bool {
        phase == .review && interval < MojiWordScheduler.matureInterval
    }

    var isUntouched: Bool {
        self == .fresh
    }

    func isBuried(on day: Int) -> Bool {
        guard let buriedUntil else { return false }
        return day < buriedUntil
    }
}

struct MojiWordReview: Codable, Equatable, Sendable {
    let at: Date
    let button: MojiWordButton?
    let kind: MojiWordReviewKind
    let interval: Int
    let lastInterval: Int
    let easeFactor: Int
    let seconds: Double

    enum CodingKeys: String, CodingKey {
        case at = "a"
        case button = "b"
        case kind = "k"
        case interval = "i"
        case lastInterval = "li"
        case easeFactor = "e"
        case seconds = "t"
    }

    init(
        at: Date,
        button: MojiWordButton?,
        kind: MojiWordReviewKind,
        interval: Int,
        lastInterval: Int,
        easeFactor: Int,
        seconds: Double
    ) {
        self.at = at
        self.button = button
        self.kind = kind
        self.interval = interval
        self.lastInterval = lastInterval
        self.easeFactor = easeFactor
        self.seconds = seconds
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        at = try container.decode(Date.self, forKey: .at)
        button = (try? container.decodeIfPresent(Int.self, forKey: .button)).flatMap(MojiWordButton.init(rawValue:))
        kind = (try? container.decodeIfPresent(Int.self, forKey: .kind)).flatMap(MojiWordReviewKind.init(rawValue:)) ?? .review
        interval = (try? container.decodeIfPresent(Int.self, forKey: .interval)) ?? 0
        lastInterval = (try? container.decodeIfPresent(Int.self, forKey: .lastInterval)) ?? 0
        easeFactor = (try? container.decodeIfPresent(Int.self, forKey: .easeFactor)) ?? 0
        seconds = (try? container.decodeIfPresent(Double.self, forKey: .seconds)) ?? 0
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(at, forKey: .at)
        try container.encodeIfPresent(button?.rawValue, forKey: .button)
        try container.encode(kind.rawValue, forKey: .kind)
        try container.encode(interval, forKey: .interval)
        if lastInterval != 0 { try container.encode(lastInterval, forKey: .lastInterval) }
        if easeFactor != 0 { try container.encode(easeFactor, forKey: .easeFactor) }
        if seconds > 0 { try container.encode((seconds * 10).rounded() / 10, forKey: .seconds) }
    }

    var delay: MojiWordDelay? {
        if interval > 0 { return .days(interval) }
        if interval < 0 { return .seconds(-interval) }
        return nil
    }
}

struct MojiWordDayStats: Codable, Equatable, Sendable {
    let day: Int
    var newCards = 0
    var reviewCards = 0
    var learnAnswers = 0
    var reviewAnswers = 0
    var relearnAnswers = 0
    var cramAnswers = 0
    var againCount = 0
    var youngPassed = 0
    var youngFailed = 0
    var maturePassed = 0
    var matureFailed = 0
    var seconds: Double = 0
    var extraNew = 0
    var extraReviews = 0

    enum CodingKeys: String, CodingKey {
        case day = "d"
        case newCards = "nc"
        case reviewCards = "rc"
        case learnAnswers = "la"
        case reviewAnswers = "ra"
        case relearnAnswers = "rl"
        case cramAnswers = "ca"
        case againCount = "ag"
        case youngPassed = "yp"
        case youngFailed = "yf"
        case maturePassed = "mp"
        case matureFailed = "mf"
        case seconds = "t"
        case extraNew = "xn"
        case extraReviews = "xr"
    }

    init(day: Int) {
        self.day = day
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(Int.self, forKey: .day)
        func count(_ key: CodingKeys) -> Int {
            max(0, (try? container.decodeIfPresent(Int.self, forKey: key)) ?? 0)
        }
        newCards = count(.newCards)
        reviewCards = count(.reviewCards)
        learnAnswers = count(.learnAnswers)
        reviewAnswers = count(.reviewAnswers)
        relearnAnswers = count(.relearnAnswers)
        cramAnswers = count(.cramAnswers)
        againCount = count(.againCount)
        youngPassed = count(.youngPassed)
        youngFailed = count(.youngFailed)
        maturePassed = count(.maturePassed)
        matureFailed = count(.matureFailed)
        seconds = max(0, (try? container.decodeIfPresent(Double.self, forKey: .seconds)) ?? 0)
        extraNew = count(.extraNew)
        extraReviews = count(.extraReviews)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(day, forKey: .day)
        let counts: [(CodingKeys, Int)] = [
            (.newCards, newCards), (.reviewCards, reviewCards), (.learnAnswers, learnAnswers),
            (.reviewAnswers, reviewAnswers), (.relearnAnswers, relearnAnswers), (.cramAnswers, cramAnswers),
            (.againCount, againCount), (.youngPassed, youngPassed), (.youngFailed, youngFailed),
            (.maturePassed, maturePassed), (.matureFailed, matureFailed), (.extraNew, extraNew),
            (.extraReviews, extraReviews)
        ]
        for (key, value) in counts where value != 0 {
            try container.encode(value, forKey: key)
        }
        if seconds > 0 {
            try container.encode((seconds * 10).rounded() / 10, forKey: .seconds)
        }
    }

    var answers: Int {
        learnAnswers + reviewAnswers + relearnAnswers + cramAnswers
    }

    var isEmpty: Bool {
        answers == 0 && extraNew == 0 && extraReviews == 0
    }
}

enum MojiWordLeechAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case suspend
    case tagOnly = "tag"

    var id: String { rawValue }
}

enum MojiWordNewOrder: String, Codable, CaseIterable, Identifiable, Sendable {
    case frequency
    case random

    var id: String { rawValue }
}

enum MojiWordReviewOrder: String, Codable, CaseIterable, Identifiable, Sendable {
    case dueThenRandom = "due_random"
    case dueThenFrequency = "due_frequency"
    case ascendingIntervals = "intervals_ascending"
    case descendingIntervals = "intervals_descending"
    case random

    var id: String { rawValue }
}

enum MojiWordNewReviewMix: String, Codable, CaseIterable, Identifiable, Sendable {
    case mix
    case newFirst = "new_first"
    case reviewsFirst = "reviews_first"

    var id: String { rawValue }
}

enum MojiWordFrontFurigana: String, Codable, CaseIterable, Identifiable, Sendable {
    case all
    case exceptWord = "except_word"
    case none

    var id: String { rawValue }
}

enum MojiWordDefaults {
    static let newPerDay = 20
    static let reviewsPerDay = 200
    static let learningSteps: [Double] = [1, 10]
    static let relearningSteps: [Double] = [10]
    static let graduatingInterval = 1
    static let easyInterval = 4
    static let startingEase = 2.5
    static let easyBonus = 1.3
    static let intervalModifier = 1.0
    static let hardInterval = 1.2
    static let newInterval = 0.0
    static let minimumInterval = 1
    static let maximumInterval = 36_500
    static let leechThreshold = 8
    static let leechAction = MojiWordLeechAction.tagOnly
    static let dayStartsAtHour = 4
    static let learnAheadSeconds = 1_200
    static let maximumAnswerSeconds = 60.0
    static let maximumStepMinutes = 60.0 * 24 * 365
}

struct MojiWordOptions: Codable, Equatable, Sendable {
    var newPerDay = MojiWordDefaults.newPerDay
    var reviewsPerDay = MojiWordDefaults.reviewsPerDay
    var learningSteps = MojiWordDefaults.learningSteps
    var relearningSteps = MojiWordDefaults.relearningSteps
    var graduatingInterval = MojiWordDefaults.graduatingInterval
    var easyInterval = MojiWordDefaults.easyInterval
    var startingEase = MojiWordDefaults.startingEase
    var easyBonus = MojiWordDefaults.easyBonus
    var intervalModifier = MojiWordDefaults.intervalModifier
    var hardInterval = MojiWordDefaults.hardInterval
    var newInterval = MojiWordDefaults.newInterval
    var minimumInterval = MojiWordDefaults.minimumInterval
    var maximumInterval = MojiWordDefaults.maximumInterval
    var leechThreshold = MojiWordDefaults.leechThreshold
    var leechAction = MojiWordDefaults.leechAction
    var newOrder = MojiWordNewOrder.frequency
    var reviewOrder = MojiWordReviewOrder.dueThenRandom
    var newReviewMix = MojiWordNewReviewMix.mix
    var burySiblings = true
    var reverseCards = false
    var frontFurigana = MojiWordFrontFurigana.all
    var autoplayAudio = true
    var replayButtons = true
    var showNextIntervals = true
    var swipeToGrade = true
    var typeReading = false
    var showTimer = true
    var dayStartsAtHour = MojiWordDefaults.dayStartsAtHour

    static let standard = MojiWordOptions()

    enum CodingKeys: String, CodingKey {
        case newPerDay
        case reviewsPerDay
        case learningSteps
        case relearningSteps
        case graduatingInterval
        case easyInterval
        case startingEase
        case easyBonus
        case intervalModifier
        case hardInterval
        case newInterval
        case minimumInterval
        case maximumInterval
        case leechThreshold
        case leechAction
        case newOrder
        case reviewOrder
        case newReviewMix
        case burySiblings
        case reverseCards
        case frontFurigana
        case autoplayAudio
        case replayButtons
        case showNextIntervals
        case swipeToGrade
        case typeReading
        case showTimer
        case dayStartsAtHour
    }

    init() {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let base = MojiWordOptions.standard
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? container.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        func choice<T: RawRepresentable>(_ key: CodingKeys, _ fallback: T) -> T where T.RawValue == String {
            (try? container.decodeIfPresent(String.self, forKey: key)).flatMap(T.init(rawValue:)) ?? fallback
        }
        newPerDay = value(.newPerDay, base.newPerDay)
        reviewsPerDay = value(.reviewsPerDay, base.reviewsPerDay)
        learningSteps = value(.learningSteps, base.learningSteps)
        relearningSteps = value(.relearningSteps, base.relearningSteps)
        graduatingInterval = value(.graduatingInterval, base.graduatingInterval)
        easyInterval = value(.easyInterval, base.easyInterval)
        startingEase = value(.startingEase, base.startingEase)
        easyBonus = value(.easyBonus, base.easyBonus)
        intervalModifier = value(.intervalModifier, base.intervalModifier)
        hardInterval = value(.hardInterval, base.hardInterval)
        newInterval = value(.newInterval, base.newInterval)
        minimumInterval = value(.minimumInterval, base.minimumInterval)
        maximumInterval = value(.maximumInterval, base.maximumInterval)
        leechThreshold = value(.leechThreshold, base.leechThreshold)
        leechAction = choice(.leechAction, base.leechAction)
        newOrder = choice(.newOrder, base.newOrder)
        reviewOrder = choice(.reviewOrder, base.reviewOrder)
        newReviewMix = choice(.newReviewMix, base.newReviewMix)
        burySiblings = value(.burySiblings, base.burySiblings)
        reverseCards = value(.reverseCards, base.reverseCards)
        frontFurigana = choice(.frontFurigana, base.frontFurigana)
        autoplayAudio = value(.autoplayAudio, base.autoplayAudio)
        replayButtons = value(.replayButtons, base.replayButtons)
        showNextIntervals = value(.showNextIntervals, base.showNextIntervals)
        swipeToGrade = value(.swipeToGrade, base.swipeToGrade)
        typeReading = value(.typeReading, base.typeReading)
        showTimer = value(.showTimer, base.showTimer)
        dayStartsAtHour = value(.dayStartsAtHour, base.dayStartsAtHour)
        self = sanitized()
    }

    func sanitized() -> MojiWordOptions {
        var options = self
        options.newPerDay = min(9_999, max(0, newPerDay))
        options.reviewsPerDay = min(99_999, max(0, reviewsPerDay))
        options.learningSteps = Self.cleanSteps(learningSteps)
        options.relearningSteps = Self.cleanSteps(relearningSteps)
        options.maximumInterval = min(36_500, max(1, maximumInterval))
        options.graduatingInterval = min(options.maximumInterval, max(1, graduatingInterval))
        options.easyInterval = min(options.maximumInterval, max(1, easyInterval))
        options.startingEase = Self.clamp(startingEase, 1.31, 5.0, fallback: MojiWordDefaults.startingEase)
        options.easyBonus = Self.clamp(easyBonus, 1.0, 5.0, fallback: MojiWordDefaults.easyBonus)
        options.intervalModifier = Self.clamp(intervalModifier, 0.5, 2.0, fallback: MojiWordDefaults.intervalModifier)
        options.hardInterval = Self.clamp(hardInterval, 0.5, 1.3, fallback: MojiWordDefaults.hardInterval)
        options.newInterval = Self.clamp(newInterval, 0.0, 1.0, fallback: MojiWordDefaults.newInterval)
        options.minimumInterval = min(options.maximumInterval, max(1, minimumInterval))
        options.leechThreshold = min(99, max(0, leechThreshold))
        options.dayStartsAtHour = min(23, max(0, dayStartsAtHour))
        return options
    }

    private static func cleanSteps(_ steps: [Double]) -> [Double] {
        Array(steps.filter { $0.isFinite && $0 > 0 }.map { min($0, MojiWordDefaults.maximumStepMinutes) }.prefix(20))
    }

    private static func clamp(_ value: Double, _ low: Double, _ high: Double, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(high, max(low, value))
    }
}

struct MojiWordLossyMap<Value: Codable>: Codable {
    let values: [String: Value]

    init(_ values: [String: Value]) {
        self.values = values
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: MojiWordAnyKey.self)
        var values: [String: Value] = [:]
        for key in container.allKeys {
            if let value = try? container.decode(Value.self, forKey: key) {
                values[key.stringValue] = value
            }
        }
        self.values = values
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }
}

extension MojiWordLossyMap: Sendable where Value: Sendable {}

private struct MojiWordAnyKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

enum MojiWordDay {
    private static let referenceComponents = DateComponents(year: 2000, month: 1, day: 1)

    static func index(of date: Date, startsAtHour hour: Int, calendar: Calendar) -> Int {
        let shifted = calendar.date(byAdding: .hour, value: -hour, to: date) ?? date
        let start = calendar.startOfDay(for: shifted)
        guard let reference = calendar.date(from: referenceComponents) else { return 0 }
        return calendar.dateComponents([.day], from: reference, to: start).day ?? 0
    }

    static func start(of day: Int, startsAtHour hour: Int, calendar: Calendar) -> Date {
        guard let reference = calendar.date(from: referenceComponents),
              let midnight = calendar.date(byAdding: .day, value: day, to: reference) else {
            return Date()
        }
        return calendar.date(byAdding: .hour, value: hour, to: midnight) ?? midnight
    }

    static func date(of day: Int, calendar: Calendar) -> Date {
        start(of: day, startsAtHour: 12, calendar: calendar)
    }
}

enum MojiWordFuzz {
    static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    static func mix(_ seed: UInt64) -> UInt64 {
        var value = seed &+ 0x9E37_79B9_7F4A_7C15
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    static func unit(_ seed: UInt64) -> Double {
        Double(mix(seed) >> 11) / Double(UInt64(1) << 53)
    }

    static func factor(for card: MojiWordCardID, reps: Int) -> Double {
        unit(stableHash(card.key) &+ UInt64(max(0, reps)))
    }

    static func dailyOrder(for card: MojiWordCardID, day: Int) -> UInt64 {
        mix(stableHash(card.key) ^ UInt64(bitPattern: Int64(day)))
    }
}
