import SwiftUI

enum WordsFormat {
    static func interval(_ delay: MojiWordDelay) -> String {
        span(MojiWordSpan(delay))
    }

    static func interval(days: Int) -> String {
        span(MojiWordSpan(days: days))
    }

    static func span(_ span: MojiWordSpan) -> String {
        switch span {
        case .minutes(let minutes, let isUpperBound):
            isUpperBound
                ? String(localized: "<\(minutes) min", comment: "Answer button interval, less than N minutes.")
                : String(localized: "\(minutes) min", comment: "Interval in minutes.")
        case .hours(let hours, let isUpperBound):
            isUpperBound
                ? String(localized: "<\(decimal(hours)) h", comment: "Answer button interval, less than N hours.")
                : String(localized: "\(decimal(hours)) h", comment: "Interval in hours.")
        case .days(let days):
            String(localized: "\(days) d", comment: "Interval in days, short.")
        case .months(let months):
            String(localized: "\(decimal(months)) mo", comment: "Interval in months, short.")
        case .years(let years):
            String(localized: "\(decimal(years)) y", comment: "Interval in years, short.")
        }
    }

    static func decimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    static func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let rest = total % 60
        return rest < 10 ? "\(minutes):0\(rest)" : "\(minutes):\(rest)"
    }

    static func duration(_ seconds: Double) -> String {
        let rounded = max(0, (seconds / 60).rounded() * 60)
        guard rounded >= 60 else {
            return Duration.seconds(max(0, seconds.rounded())).formatted(.units(allowed: [.seconds], width: .abbreviated))
        }
        return Duration.seconds(rounded).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    static func percent(_ value: Double?) -> String {
        guard let value else { return "-" }
        return value.formatted(.percent.precision(.fractionLength(0)))
    }

    static func date(ofDay day: Int) -> Date {
        MojiWordDay.date(of: day, calendar: .current)
    }

    static func due(_ card: MojiWordCard, today: Int) -> String {
        if card.isSuspended {
            return String(localized: "Suspended")
        }
        if card.isNew {
            return String(localized: "Not studied yet")
        }
        if let dueAt = card.dueAt {
            return dueAt <= Date()
                ? String(localized: "Due now")
                : String(localized: "Due at \(dueAt.formatted(date: .omitted, time: .shortened))")
        }
        guard let dueDay = card.dueDay else { return String(localized: "Not studied yet") }
        switch dueDay - today {
        case ..<0:
            return String(localized: "Overdue since \(date(ofDay: dueDay).formatted(.dateTime.day().month()))")
        case 0:
            return String(localized: "Due today")
        case 1:
            return String(localized: "Due tomorrow")
        default:
            return String(localized: "Due \(date(ofDay: dueDay).formatted(.dateTime.day().month().year()))")
        }
    }
}

extension MojiWordButton {
    var title: String {
        switch self {
        case .again: String(localized: "Again")
        case .hard: String(localized: "Hard")
        case .good: String(localized: "Good")
        case .easy: String(localized: "Easy")
        }
    }

    var tint: Color? {
        switch self {
        case .again: MojiTint.wrong
        case .good: MojiTint.correct
        case .hard, .easy: nil
        }
    }
}

extension MojiWordCardState {
    var title: String {
        switch self {
        case .new: String(localized: "New")
        case .learning: String(localized: "Learning")
        case .relearning: String(localized: "Relearning")
        case .young: String(localized: "Young")
        case .mature: String(localized: "Mature")
        case .suspended: String(localized: "Suspended")
        case .buried: String(localized: "Buried")
        }
    }

    var badge: String {
        switch self {
        case .new: String(localized: "new")
        case .learning: String(localized: "learning")
        case .relearning: String(localized: "relearning")
        case .young: String(localized: "young")
        case .mature: String(localized: "mature")
        case .suspended: String(localized: "suspended")
        case .buried: String(localized: "buried")
        }
    }
}

extension MojiWordPartOfSpeech {
    var title: String {
        switch self {
        case .noun: String(localized: "noun")
        case .nounSuru: String(localized: "noun, also with する")
        case .prenominal: String(localized: "pre-noun word")
        case .pronoun: String(localized: "pronoun")
        case .verb: String(localized: "verb")
        case .adjectiveI: String(localized: "i-adjective")
        case .adjectiveNa: String(localized: "na-adjective")
        case .adverb: String(localized: "adverb")
        case .particle: String(localized: "particle")
        case .conjunction: String(localized: "conjunction")
        case .interjection: String(localized: "interjection")
        case .expression: String(localized: "expression")
        case .counter: String(localized: "counter")
        case .number: String(localized: "number")
        case .prefix: String(localized: "prefix")
        case .suffix: String(localized: "suffix")
        case .auxiliary: String(localized: "auxiliary")
        }
    }
}

extension MojiWordFlag {
    var title: String {
        switch self {
        case .red: String(localized: "Red")
        case .orange: String(localized: "Orange")
        case .green: String(localized: "Green")
        case .blue: String(localized: "Blue")
        case .pink: String(localized: "Pink")
        case .turquoise: String(localized: "Turquoise")
        case .purple: String(localized: "Purple")
        }
    }

    var color: Color {
        switch self {
        case .red: Color(hex: "#E5484D")
        case .orange: Color(hex: "#F08A24")
        case .green: Color(hex: "#30A46C")
        case .blue: Color(hex: "#3E7BFA")
        case .pink: Color(hex: "#E93D82")
        case .turquoise: Color(hex: "#12A594")
        case .purple: Color(hex: "#8E4EC6")
        }
    }
}

extension MojiWordReviewKind {
    var title: String {
        switch self {
        case .learn: String(localized: "Learn")
        case .review: String(localized: "Review")
        case .relearn: String(localized: "Relearn")
        case .cram: String(localized: "Extra practice")
        case .manual: String(localized: "Changed by you")
        }
    }
}

extension MojiWordLeechAction {
    var title: String {
        switch self {
        case .suspend: String(localized: "Suspend the card")
        case .tagOnly: String(localized: "Only tag it")
        }
    }
}

extension MojiWordNewOrder {
    var title: String {
        switch self {
        case .frequency: String(localized: "Most frequent first")
        case .random: String(localized: "Random")
        }
    }
}

extension MojiWordReviewOrder {
    var title: String {
        switch self {
        case .dueThenRandom: String(localized: "Due date, then random")
        case .dueThenFrequency: String(localized: "Due date, then frequency")
        case .ascendingIntervals: String(localized: "Shortest intervals first")
        case .descendingIntervals: String(localized: "Longest intervals first")
        case .random: String(localized: "Random")
        }
    }
}

extension MojiWordNewReviewMix {
    var title: String {
        switch self {
        case .mix: String(localized: "Mix with reviews")
        case .newFirst: String(localized: "Before reviews")
        case .reviewsFirst: String(localized: "After reviews")
        }
    }
}

extension MojiWordFrontFurigana {
    var title: String {
        switch self {
        case .all: String(localized: "Over every kanji")
        case .exceptWord: String(localized: "All but the word itself")
        case .none: String(localized: "None")
        }
    }
}
