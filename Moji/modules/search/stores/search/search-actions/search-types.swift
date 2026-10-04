import Foundation

enum CharacterSearchSurface: Hashable, Sendable {
    case learn
    case practice
}

enum CharacterSearchMark: Equatable, Sendable {
    case unmatched
    case match
    case current
}

struct CharacterSearchFocus: Equatable, Sendable {
    let page: MojiPage
    let characterID: String
    let token: Int
}

struct CharacterSearchState: Equatable, Sendable {
    var query = ""
    var script: MojiScript?
    var ordered: [String] = []
    var found: Set<String> = []
    var position = 0
    var focus: CharacterSearchFocus?

    func mark(_ characterID: String, in script: MojiScript) -> CharacterSearchMark {
        guard self.script == script, found.contains(characterID) else { return .unmatched }
        return focus?.characterID == characterID ? .current : .match
    }

    func counter(for script: MojiScript) -> (current: Int, total: Int)? {
        guard !query.isEmpty, self.script == script else { return nil }
        return (ordered.isEmpty || focus == nil ? 0 : position + 1, ordered.count)
    }
}
