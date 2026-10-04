import Foundation

enum MojiQuizDirection: String, Codable, Sendable {
    case glyphToRomaji = "glyph_to_romaji"
    case romajiToGlyph = "romaji_to_glyph"
}

enum MojiQuizInput: String, Codable, Sendable {
    case choice
    case typing
}

struct MojiQuizQuestion: Codable, Equatable, Sendable {
    let characterID: String
    let direction: MojiQuizDirection
    let optionIDs: [String]
    let input: MojiQuizInput

    init(
        characterID: String,
        direction: MojiQuizDirection,
        optionIDs: [String],
        input: MojiQuizInput = .choice
    ) {
        self.characterID = characterID
        self.direction = direction
        self.optionIDs = optionIDs
        self.input = input
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        characterID = try container.decode(String.self, forKey: .characterID)
        direction = try container.decode(MojiQuizDirection.self, forKey: .direction)
        optionIDs = try container.decode([String].self, forKey: .optionIDs)
        input = (try? container.decodeIfPresent(MojiQuizInput.self, forKey: .input)) ?? .choice
    }
}

struct MojiQuizAnswer: Codable, Equatable, Sendable {
    let characterID: String
    let chosenID: String?
    var typed: String? = nil
    let isCorrect: Bool
    let answeredAt: Date
}

struct MojiPracticeSession: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let page: MojiPage
    let order: [String]
    var answers: [MojiQuizAnswer]
    var current: MojiQuizQuestion?
    var combo: Int
    var bestCombo: Int
    let startedAt: Date
    var updatedAt: Date
    var activeSeconds: Double

    enum CodingKeys: String, CodingKey {
        case id
        case page
        case order
        case answers
        case current
        case combo
        case bestCombo
        case startedAt
        case updatedAt
        case activeSeconds
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case script
    }

    var script: MojiScript {
        page.script
    }

    var answeredCount: Int {
        answers.count
    }

    var total: Int {
        order.count
    }

    var isComplete: Bool {
        answers.count >= order.count
    }

    var correctCount: Int {
        answers.reduce(0) { $0 + ($1.isCorrect ? 1 : 0) }
    }

    var progress: Double {
        total > 0 ? Double(answeredCount) / Double(total) : 0
    }
}

extension MojiPracticeSession {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let page: MojiPage
        if let stored = try container.decodeIfPresent(MojiPage.self, forKey: .page) {
            page = stored
        } else {
            let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
            let script = try legacy.decode(String.self, forKey: .script)
            guard let legacyPage = MojiPage(rawValue: script) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .script,
                    in: legacy,
                    debugDescription: "A session of the retired \(script) page"
                )
            }
            page = legacyPage
        }
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            page: page,
            order: try container.decode([String].self, forKey: .order),
            answers: try container.decode([MojiQuizAnswer].self, forKey: .answers),
            current: try container.decodeIfPresent(MojiQuizQuestion.self, forKey: .current),
            combo: try container.decode(Int.self, forKey: .combo),
            bestCombo: try container.decode(Int.self, forKey: .bestCombo),
            startedAt: try container.decode(Date.self, forKey: .startedAt),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt),
            activeSeconds: try container.decode(Double.self, forKey: .activeSeconds)
        )
    }
}

struct MojiCharacterProgress: Codable, Equatable, Sendable {
    static let masteryLevel = 5

    var strength: Int
    var seen: Int
    var correct: Int
    var lastSeenAt: Date?

    static let fresh = MojiCharacterProgress(
        strength: 0,
        seen: 0,
        correct: 0,
        lastSeenAt: nil
    )

    var isMastered: Bool {
        strength >= Self.masteryLevel
    }

    var mastery: Double {
        Double(min(strength, Self.masteryLevel)) / Double(Self.masteryLevel)
    }

    var accuracy: Double? {
        seen > 0 ? Double(correct) / Double(seen) : nil
    }

    func recording(correct isCorrect: Bool, at date: Date, steps: Int = 1) -> MojiCharacterProgress {
        MojiCharacterProgress(
            strength: isCorrect ? min(Self.masteryLevel, strength + max(1, steps)) : max(0, strength - 2),
            seen: seen + 1,
            correct: correct + (isCorrect ? 1 : 0),
            lastSeenAt: date
        )
    }
}

enum MojiActivityKind: String, Codable, Sendable {
    case session
    case lesson
    case words
}

struct MojiCompletedSession: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let page: MojiPage?
    let script: MojiScript
    let dayKey: String
    let startedAt: Date
    let completedAt: Date
    let total: Int
    let correct: Int
    let bestCombo: Int
    let activeSeconds: Double
    let mistakeIDs: [String]
    var kind: MojiActivityKind? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case page
        case script
        case dayKey
        case startedAt
        case completedAt
        case total
        case correct
        case bestCombo
        case activeSeconds
        case mistakeIDs
        case kind
    }

    var isLesson: Bool {
        kind == .lesson
    }
}

extension MojiCompletedSession {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedScript = try container.decode(String.self, forKey: .script)
        guard let script = MojiScript(storedValue: storedScript) else {
            throw DecodingError.dataCorruptedError(
                forKey: .script,
                in: container,
                debugDescription: "Unknown script \(storedScript)"
            )
        }
        let storedPage = try container.decodeIfPresent(String.self, forKey: .page)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            page: storedPage.flatMap(MojiPage.init(rawValue:)) ?? MojiPage(rawValue: storedScript),
            script: script,
            dayKey: try container.decode(String.self, forKey: .dayKey),
            startedAt: try container.decode(Date.self, forKey: .startedAt),
            completedAt: try container.decode(Date.self, forKey: .completedAt),
            total: try container.decode(Int.self, forKey: .total),
            correct: try container.decode(Int.self, forKey: .correct),
            bestCombo: try container.decode(Int.self, forKey: .bestCombo),
            activeSeconds: try container.decode(Double.self, forKey: .activeSeconds),
            mistakeIDs: try container.decode([String].self, forKey: .mistakeIDs),
            kind: (try? container.decodeIfPresent(MojiActivityKind.self, forKey: .kind)) ?? nil
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(page?.rawValue, forKey: .page)
        try container.encode(script.rawValue, forKey: .script)
        try container.encode(dayKey, forKey: .dayKey)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(completedAt, forKey: .completedAt)
        try container.encode(total, forKey: .total)
        try container.encode(correct, forKey: .correct)
        try container.encode(bestCombo, forKey: .bestCombo)
        try container.encode(activeSeconds, forKey: .activeSeconds)
        try container.encode(mistakeIDs, forKey: .mistakeIDs)
        try container.encodeIfPresent(kind, forKey: .kind)
    }
}

struct MojiActivityLog: Codable, Equatable, Sendable {
    static let maxEntries = 5_000

    var completed: [MojiCompletedSession]

    enum CodingKeys: String, CodingKey {
        case completed
    }

    static let empty = MojiActivityLog(completed: [])
}

extension MojiActivityLog {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        completed = try container.decode(MojiLossyArray<MojiCompletedSession>.self, forKey: .completed).elements
    }
}

struct MojiPageStats: Equatable, Sendable {
    let total: Int
    let practiced: Int
    let mastered: Int

    static func empty(total: Int) -> MojiPageStats {
        MojiPageStats(
            total: total,
            practiced: 0,
            mastered: 0
        )
    }
}

struct MojiActivitySummary: Equatable, Sendable {
    let todayKey: String
    let dayCounts: [String: Int]
    let currentStreak: Int
    let bestStreak: Int
    let isTodayDone: Bool
    let practicedDays: Int
    let totalSessions: Int
    let pagesDoneToday: Set<MojiPage>
    let firstYear: Int

    static let empty = MojiActivitySummary(
        todayKey: "",
        dayCounts: [:],
        currentStreak: 0,
        bestStreak: 0,
        isTodayDone: false,
        practicedDays: 0,
        totalSessions: 0,
        pagesDoneToday: [],
        firstYear: Calendar.current.component(.year, from: Date())
    )
}

struct MojiAnswerSubmission: Sendable {
    let page: MojiPage
    let sessionID: UUID
    let questionIndex: Int
    let chosenID: String?
    let thinkSeconds: Double
    let answeredAt: Date
    var typed: String? = nil
}

struct MojiPracticeCompletion: Equatable, Sendable {
    let record: MojiCompletedSession
    let page: MojiPage
    let streak: Int
    let extendedStreak: Bool
}

enum MojiPracticeAnswerOutcome: Equatable, Sendable {
    case next(MojiPracticeSession)
    case completed(MojiPracticeCompletion)
}
