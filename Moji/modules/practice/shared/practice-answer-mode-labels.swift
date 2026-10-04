import Foundation

extension MojiAnswerInput {
    var title: String {
        switch self {
        case .list: String(localized: "List")
        case .keyboard: String(localized: "Keyboard")
        case .mixed: String(localized: "List and keyboard")
        case .drawing: String(localized: "Drawing")
        }
    }

    var systemImage: String {
        switch self {
        case .list: "list.bullet"
        case .keyboard: "keyboard"
        case .mixed: "shuffle"
        case .drawing: "hand.draw"
        }
    }

    func caption(for script: MojiScript) -> String {
        switch self {
        case .list:
            String(localized: "Pick the answer from four options.")
        case .keyboard:
            script.isKanji
                ? String(localized: "Type the reading in romaji, or the kanji on the Japanese keyboard.")
                : String(localized: "Type the romaji, or the kana on the Japanese keyboard.")
        case .mixed:
            String(localized: "Each question picks the list or the keyboard at random.")
        case .drawing:
            script.isKanji
                ? String(localized: "See the meaning and draw the kanji stroke by stroke.")
                : String(localized: "See the romaji and draw the character stroke by stroke.")
        }
    }
}

extension MojiAnswerSide {
    func title(for script: MojiScript) -> String {
        switch self {
        case .romaji:
            script.isKanji ? String(localized: "Meaning or reading") : String(localized: "Romaji")
        case .character:
            script.title
        case .mixed:
            String(localized: "Both ways")
        }
    }

    func caption(for script: MojiScript) -> String {
        let glyph = script.symbol
        switch self {
        case .romaji:
            return script.isKanji
                ? String(localized: "You see \(glyph) and give its meaning, or type its reading.")
                : String(localized: "You see \(glyph) and answer a.")
        case .character:
            return script.isKanji
                ? String(localized: "You see a meaning and answer with the kanji.")
                : String(localized: "You see a and answer \(glyph).")
        case .mixed:
            return String(localized: "Each question picks a side at random.")
        }
    }

    func arrow(for script: MojiScript) -> String {
        switch self {
        case .romaji: "\(script.symbol) → a"
        case .character: "a → \(script.symbol)"
        case .mixed: "\(script.symbol) ⇄ a"
        }
    }
}
