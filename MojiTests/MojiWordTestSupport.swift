import Foundation
@testable import Moji

enum MojiWordTestSupport {
    static let now = Date(timeIntervalSince1970: 1_790_000_000)

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    static let deckURLs: [URL] = {
        let relative = "Moji/Resources/WordDeck/\(MojiWordCatalog.resourceName).\(MojiWordCatalog.resourceExtension)"
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let working = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return [source.appendingPathComponent(relative), working.appendingPathComponent(relative)]
    }()

    static let deck: MojiWordCatalog = {
        let bundled = MojiWordCatalog.bundled()
        if !bundled.isEmpty {
            return bundled
        }
        for url in deckURLs {
            if let catalog = MojiWordCatalog.load(from: url), !catalog.isEmpty {
                return catalog
            }
        }
        return .empty
    }()

    static func catalog(count: Int, sectionSize: Int = 10) -> MojiWordCatalog {
        let words = (1...max(1, count)).map { index in
            MojiWord(
                id: "t\(index)",
                written: "語\(index)",
                reading: "ご",
                romaji: "go",
                english: "word \(index)",
                russian: "слово \(index)",
                rank: index,
                section: (index - 1) / sectionSize + 1,
                partOfSpeech: .noun,
                sentences: []
            )
        }
        return MojiWordCatalog(words: words, credits: [])
    }

    static func context(_ options: MojiWordOptions = .standard, at date: Date = now) -> MojiWordSchedulingContext {
        MojiWordSchedulingContext(options: options, now: date, calendar: calendar)
    }

    static func id(_ index: Int, _ kind: MojiWordCardKind = .recognition) -> MojiWordCardID {
        MojiWordCardID(wordID: "t\(index)", kind: kind)
    }

    static func review(dueDay: Int, interval: Int = 5, ease: Int = 2_500) -> MojiWordCard {
        var card = MojiWordCard()
        card.phase = .review
        card.dueDay = dueDay
        card.interval = interval
        card.easeFactor = ease
        card.reps = 3
        return card
    }

    static func learning(dueAt: Date, remaining: Int = 1) -> MojiWordCard {
        var card = MojiWordCard()
        card.phase = .learning
        card.dueAt = dueAt
        card.remainingSteps = remaining
        card.reps = 1
        return card
    }

    static func scratchDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("moji-words-\(UUID().uuidString)", isDirectory: true)
    }

    static func repository(
        at directory: URL,
        catalog: MojiWordCatalog
    ) -> MojiWordRepository {
        MojiWordRepository(
            resources: MojiWordResourceRepository(store: MojiDiskStore(directory: directory)),
            catalogLoader: { catalog },
            calendar: calendar,
            learningFuzz: { 0 }
        )
    }

    static func writeEnvelope(_ value: String, name: String, in directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let envelope = #"{"savedAt":0,"value":"# + value + #","version":1}"#
        try Data(envelope.utf8).write(to: directory.appendingPathComponent(name))
    }
}
