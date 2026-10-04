import Foundation

struct WordsPresentedStudy: Identifiable, Equatable {
    let scope: MojiWordScope
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
