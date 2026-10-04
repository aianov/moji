import Foundation

struct WordsPresentedStudy: Identifiable, Equatable {
    let scope: MojiWordScope
    let deck: MojiWordDeck
    let token: UUID

    var id: UUID { token }
}

enum WordsStudyStage: Equatable {
    case loading
    case card(MojiWordStudyCard)
    case finished(WordsStudySummaryModel)
}

struct WordsStudySummaryModel: Equatable {
    let summary: MojiWordSessionSummary
    let streak: Int?
    let extendedStreak: Bool

    var accuracy: Double? {
        summary.answered > 0 ? Double(summary.correct) / Double(summary.answered) : nil
    }
}

enum WordsSheet: String, Identifiable {
    case options
    case browser
    case stats
    case customStudy

    var id: String { rawValue }
}

struct WordsDetailTarget: Identifiable, Equatable {
    let wordID: String

    var id: String { wordID }
}

enum WordsSectionActionKind: Equatable {
    case known
    case reset
}

struct WordsSectionAction: Identifiable, Equatable {
    let kind: WordsSectionActionKind
    let section: MojiWordSection

    var id: String { "\(kind)#\(section.number)" }
}

enum WordsBrowserFilter: String, CaseIterable, Identifiable {
    case all
    case new
    case learning
    case young
    case mature
    case suspended
    case flagged
    case leech
    case due

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .new: String(localized: "New")
        case .learning: String(localized: "Learning")
        case .young: String(localized: "Young")
        case .mature: String(localized: "Mature")
        case .suspended: String(localized: "Suspended")
        case .flagged: String(localized: "Flagged")
        case .leech: String(localized: "Leeches")
        case .due: String(localized: "Due today")
        }
    }

    func matches(_ card: MojiWordCard, today: Int) -> Bool {
        switch self {
        case .all: true
        case .new: card.isNew && !card.isSuspended
        case .learning: card.isInLearning && !card.isSuspended
        case .young: card.isYoung && !card.isSuspended
        case .mature: card.isMature && !card.isSuspended
        case .suspended: card.isSuspended
        case .flagged: card.flag != nil
        case .leech: card.isLeech
        case .due: MojiWordStats.isDue(card, today: today)
        }
    }
}

struct WordsFlyAway: Equatable {
    let button: MojiWordButton
    let token: Int
}

struct WordsLeechNotice: Equatable, Identifiable {
    let word: String
    let suspended: Bool
    let token: UUID

    var id: UUID { token }
}

enum WordsTypedVerdict: Equatable {
    case right
    case wrong(typed: String)
    case skipped
}

struct WordsCustomStudyDraft: Equatable {
    var extraNew = 10
    var extraReviews = 50
    var forgottenDays = 1
    var aheadDays = 3
    var section = 1
}

enum WordsCardOrigin: Equatable {
    case page
    case detail
}

struct WordsCardEditor: Identifiable, Equatable {
    let wordID: String?
    let origin: WordsCardOrigin
    let token: UUID

    var id: UUID { token }

    var isNew: Bool {
        wordID == nil
    }
}

enum WordsCardField: Hashable {
    case word
    case reading
    case meaning
    case sentence
    case translation
    case note
    case fix(String)
}

struct WordsCardDraft: Equatable {
    var word = ""
    var reading = ""
    var autoReading = ""
    var isReadingEdited = false
    var meaning = ""
    var sentence = ""
    var autoTokens: [MojiWordToken] = []
    var tokens: [MojiWordToken] = []
    var fixes: [String: String] = [:]
    var translation = ""
    var note = ""
    var lastAdded: String?
    var original: MojiOwnWordInput?

    var input: MojiOwnWordInput {
        MojiOwnWordInput(
            written: word,
            reading: reading,
            meaning: meaning,
            sentence: tokens,
            translation: translation,
            note: note
        )
    }

    var problems: [MojiOwnWordProblem] {
        input.problems
    }

    var isEmpty: Bool {
        [word, meaning, sentence, translation, note].allSatisfy {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var hasChanges: Bool {
        guard let original else { return !isEmpty }
        return input.cleaned() != original.cleaned()
    }

    var fixableTokens: [MojiWordToken] {
        var seen: Set<String> = []
        return tokens.filter { $0.hasKanji && seen.insert($0.surface).inserted }
    }

    func autoReading(of surface: String) -> String? {
        autoTokens.first { $0.surface == surface }?.reading
    }
}

struct WordsDeleteRequest: Identifiable, Equatable {
    let wordID: String
    let written: String
    let origin: WordsCardOrigin

    var id: String { wordID }
}
