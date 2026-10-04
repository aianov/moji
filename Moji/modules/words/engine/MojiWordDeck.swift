import Foundation

enum MojiWordDeck: String, CaseIterable, Identifiable, Sendable {
    case frequent
    case mine

    var id: String { rawValue }

    static func of(wordID: String) -> MojiWordDeck {
        MojiOwnWord.isOwnID(wordID) ? .mine : .frequent
    }
}
