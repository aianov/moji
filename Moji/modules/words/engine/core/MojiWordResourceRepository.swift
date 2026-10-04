import Foundation

struct MojiWordCache: Sendable {
    let cards: [String: MojiWordCard]
    let history: [String: [MojiWordReview]]
    let days: [Int: MojiWordDayStats]
    let options: MojiWordOptions
    let notes: [String: String]
    let ownWords: [MojiOwnWord]
}

struct MojiWordResourceRepository: Sendable {
    private static let version = 1
    private static let namespace = "words"
    private static let ownWordsKey = MojiDiskKey(namespace: namespace, name: "mine")

    let store: MojiDiskStore
    var deck: MojiWordDeck = .frequent

    private var cardsKey: MojiDiskKey { key("cards") }
    private var historyKey: MojiDiskKey { key("history") }
    private var daysKey: MojiDiskKey { key("days") }
    private var optionsKey: MojiDiskKey { key("options") }
    private var notesKey: MojiDiskKey { key("notes") }

    func load() async -> MojiWordCache {
        let cards = await store.read(MojiWordLossyMap<MojiWordCard>.self, key: cardsKey, version: Self.version)
        let history = await store.read(MojiWordLossyMap<MojiLossyArray<MojiWordReview>>.self, key: historyKey, version: Self.version)
        let days = await store.read(MojiLossyArray<MojiWordDayStats>.self, key: daysKey, version: Self.version)
        let options = await store.read(MojiWordOptions.self, key: optionsKey, version: Self.version)

        var notes: [String: String] = [:]
        var ownWords: [MojiOwnWord] = []
        switch deck {
        case .frequent:
            notes = await store.read(MojiWordLossyMap<String>.self, key: notesKey, version: Self.version)?.values ?? [:]
        case .mine:
            let stored = await store.read(MojiLossyArray<MojiOwnWord>.self, key: Self.ownWordsKey, version: Self.version)
            var seen: Set<String> = []
            ownWords = (stored?.elements ?? []).filter { seen.insert($0.id).inserted }
        }

        var dayMap: [Int: MojiWordDayStats] = [:]
        for entry in days?.elements ?? [] {
            dayMap[entry.day] = entry
        }
        return MojiWordCache(
            cards: cards?.values ?? [:],
            history: (history?.values ?? [:]).mapValues(\.elements),
            days: dayMap,
            options: options ?? .standard,
            notes: notes,
            ownWords: ownWords
        )
    }

    func saveCards(_ cards: [String: MojiWordCard]) async {
        await store.write(MojiWordLossyMap(cards), key: cardsKey, version: Self.version)
    }

    func saveHistory(_ history: [String: [MojiWordReview]]) async {
        await store.write(
            MojiWordLossyMap(history.mapValues { MojiLossyArray($0) }),
            key: historyKey,
            version: Self.version
        )
    }

    func saveDays(_ days: [Int: MojiWordDayStats]) async {
        let ordered = days.values.sorted { $0.day < $1.day }
        await store.write(MojiLossyArray(ordered), key: daysKey, version: Self.version)
    }

    func saveOptions(_ options: MojiWordOptions) async {
        await store.write(options, key: optionsKey, version: Self.version)
    }

    func saveNotes(_ notes: [String: String]) async {
        guard deck == .frequent else { return }
        await store.write(MojiWordLossyMap(notes), key: notesKey, version: Self.version)
    }

    func saveOwnWords(_ words: [MojiOwnWord]) async {
        guard deck == .mine else { return }
        await store.write(MojiLossyArray(words), key: Self.ownWordsKey, version: Self.version)
    }

    func clearProgress() async {
        await store.remove(cardsKey)
        await store.remove(historyKey)
        await store.remove(daysKey)
    }

    private func key(_ name: String) -> MojiDiskKey {
        switch deck {
        case .frequent: MojiDiskKey(namespace: Self.namespace, name: name)
        case .mine: MojiDiskKey(namespace: Self.namespace, name: "mine-" + name)
        }
    }
}
