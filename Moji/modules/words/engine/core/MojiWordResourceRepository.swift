import Foundation

struct MojiWordCache: Sendable {
    let cards: [String: MojiWordCard]
    let history: [String: [MojiWordReview]]
    let days: [Int: MojiWordDayStats]
    let options: MojiWordOptions
    let notes: [String: String]
}

struct MojiWordResourceRepository: Sendable {
    private static let version = 1
    private static let cardsKey = MojiDiskKey(namespace: "words", name: "cards")
    private static let historyKey = MojiDiskKey(namespace: "words", name: "history")
    private static let daysKey = MojiDiskKey(namespace: "words", name: "days")
    private static let optionsKey = MojiDiskKey(namespace: "words", name: "options")
    private static let notesKey = MojiDiskKey(namespace: "words", name: "notes")

    let store: MojiDiskStore

    func load() async -> MojiWordCache {
        let cards = await store.read(MojiWordLossyMap<MojiWordCard>.self, key: Self.cardsKey, version: Self.version)
        let history = await store.read(MojiWordLossyMap<MojiLossyArray<MojiWordReview>>.self, key: Self.historyKey, version: Self.version)
        let days = await store.read(MojiLossyArray<MojiWordDayStats>.self, key: Self.daysKey, version: Self.version)
        let options = await store.read(MojiWordOptions.self, key: Self.optionsKey, version: Self.version)
        let notes = await store.read(MojiWordLossyMap<String>.self, key: Self.notesKey, version: Self.version)

        var dayMap: [Int: MojiWordDayStats] = [:]
        for entry in days?.elements ?? [] {
            dayMap[entry.day] = entry
        }
        return MojiWordCache(
            cards: cards?.values ?? [:],
            history: (history?.values ?? [:]).mapValues(\.elements),
            days: dayMap,
            options: options ?? .standard,
            notes: notes?.values ?? [:]
        )
    }

    func saveCards(_ cards: [String: MojiWordCard]) async {
        await store.write(MojiWordLossyMap(cards), key: Self.cardsKey, version: Self.version)
    }

    func saveHistory(_ history: [String: [MojiWordReview]]) async {
        await store.write(
            MojiWordLossyMap(history.mapValues { MojiLossyArray($0) }),
            key: Self.historyKey,
            version: Self.version
        )
    }

    func saveDays(_ days: [Int: MojiWordDayStats]) async {
        let ordered = days.values.sorted { $0.day < $1.day }
        await store.write(MojiLossyArray(ordered), key: Self.daysKey, version: Self.version)
    }

    func saveOptions(_ options: MojiWordOptions) async {
        await store.write(options, key: Self.optionsKey, version: Self.version)
    }

    func saveNotes(_ notes: [String: String]) async {
        await store.write(MojiWordLossyMap(notes), key: Self.notesKey, version: Self.version)
    }

    func clearProgress() async {
        await store.remove(Self.cardsKey)
        await store.remove(Self.historyKey)
        await store.remove(Self.daysKey)
    }
}
