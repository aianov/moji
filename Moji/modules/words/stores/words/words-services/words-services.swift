import Foundation
import Observation

@MainActor
@Observable
final class WordsServicesStore {
    static let shared = WordsServicesStore()

    static let deckKey = "moji.words.deck.v1"

    var selectedDeck: MojiWordDeck
    var query = ""
    var myQuery = ""
    var sheet: WordsSheet?
    var sheetDeck: MojiWordDeck = .frequent
    var detail: WordsDetailTarget?
    var detailCharacter: MojiCharacter?
    var histories: [String: [MojiWordCardID: [MojiWordReview]]] = [:]
    var sectionAction: WordsSectionAction?
    var isResetAllPresented = false

    var browserQuery = ""
    var browserFilter: WordsBrowserFilter = .all
    var browserSection: Int?

    var customStudy = WordsCustomStudyDraft()
    var customStudyCounts: [MojiWordScope: MojiWordQueueCounts] = [:]
    var optionsOverrides: [MojiWordDeck: MojiWordOptions] = [:]
    var stepDraft = ""
    var relearnStepDraft = ""
    var dueDraft = 1

    var editor: WordsCardEditor?
    var draft = WordsCardDraft()
    var isSavingCard = false
    var isDiscardCardPresented = false
    var cardFocusToken = 0
    var deleteRequest: WordsDeleteRequest?

    var presented: WordsPresentedStudy?
    var stage: WordsStudyStage = .loading
    var isFlipped = false
    var typedReading = ""
    var typedVerdict: WordsTypedVerdict?
    var flyAway: WordsFlyAway?
    var leechNotice: WordsLeechNotice?
    var studyCharacter: MojiCharacter?
    var isExitAlertPresented = false
    var isBusy = false
    var cardShownAt = Date()

    @ObservationIgnored var flyCount = 0
    @ObservationIgnored private var segmentCache: [String: [MojiRubySegment]] = [:]
    @ObservationIgnored private var searchCache: [MojiWordDeck: (query: String, catalog: MojiWordCatalog, ids: [String])] = [:]
    @ObservationIgnored private var dictionaryCache: (catalog: MojiWordCatalog, dictionary: MojiWordReadingDictionary)?

    private init() {
        selectedDeck = Self.storedDeck()
    }

    func reloadFromDefaults() {
        let stored = Self.storedDeck()
        guard stored != selectedDeck else { return }
        selectedDeck = stored
    }

    private static func storedDeck() -> MojiWordDeck {
        UserDefaults.standard
            .string(forKey: deckKey)
            .flatMap(MojiWordDeck.init(rawValue:)) ?? .frequent
    }

    func snapshot(_ deck: MojiWordDeck) -> MojiWordRepositorySnapshot {
        MojiWordPresentation.shared.snapshot(for: deck)
    }

    func catalog(_ deck: MojiWordDeck) -> MojiWordCatalog {
        snapshot(deck).catalog
    }

    func options(_ deck: MojiWordDeck) -> MojiWordOptions {
        optionsOverrides[deck] ?? snapshot(deck).options
    }

    func isLoaded(_ deck: MojiWordDeck) -> Bool {
        snapshot(deck).isLoaded
    }

    func canStudy(_ deck: MojiWordDeck) -> Bool {
        let snapshot = snapshot(deck)
        return snapshot.isLoaded && (snapshot.queue.total > 0 || snapshot.nextLearningAt != nil)
    }

    var studyDeck: MojiWordDeck {
        presented?.deck ?? selectedDeck
    }

    var activity: MojiActivitySummary {
        MojiPracticePresentation.shared.snapshot.activity
    }

    var currentCard: MojiWordStudyCard? {
        guard case .card(let card) = stage else { return nil }
        return card
    }

    var readingDictionary: MojiWordReadingDictionary {
        let catalog = catalog(.frequent)
        if let dictionaryCache, dictionaryCache.catalog === catalog {
            return dictionaryCache.dictionary
        }
        let dictionary = MojiWordReadingDictionary(catalog: catalog)
        dictionaryCache = (catalog, dictionary)
        return dictionary
    }

    func word(_ wordID: String) -> MojiWord? {
        catalog(MojiWordDeck.of(wordID: wordID)).word(wordID)
    }

    func card(_ id: MojiWordCardID) -> MojiWordCard {
        snapshot(MojiWordDeck.of(wordID: id.wordID)).card(id)
    }

    func today(of wordID: String) -> Int {
        snapshot(MojiWordDeck.of(wordID: wordID)).today
    }

    func cardIDs(of word: MojiWord) -> [MojiWordCardID] {
        MojiWordStats.cardIDs(of: word, options: options(MojiWordDeck.of(wordID: word.id)))
    }

    func allCardIDs(of word: MojiWord) -> [MojiWordCardID] {
        let ids = cardIDs(of: word)
        let reverse = MojiWordCardID(wordID: word.id, kind: .recall)
        if !ids.contains(reverse), snapshot(MojiWordDeck.of(wordID: word.id)).cards[reverse.key] != nil {
            return ids + [reverse]
        }
        return ids
    }

    func state(of word: MojiWord) -> MojiWordCardState {
        MojiWordCardState.of(card(MojiWordCardID(wordID: word.id)), today: today(of: word.id))
    }

    func sectionStats(_ section: MojiWordSection, deck: MojiWordDeck) -> MojiWordSectionStats {
        snapshot(deck).sections[section.number] ?? MojiWordSectionStats(number: section.number)
    }

    func note(for word: MojiWord) -> String? {
        snapshot(MojiWordDeck.of(wordID: word.id)).notes[word.id]
    }

    func kanjiCharacters(of word: MojiWord) -> [MojiCharacter] {
        word.kanji.compactMap { MojiAlphabetCatalog.shared.character("j-\($0)") }
    }

    func segments(for token: MojiWordToken) -> [MojiRubySegment] {
        let key = "\(token.surface)|\(token.reading ?? "")"
        if let cached = segmentCache[key] {
            return cached
        }
        let segments = MojiFurigana.segments(surface: token.surface, reading: token.reading, catalog: .shared)
        segmentCache[key] = segments
        return segments
    }

    func searchResults(_ query: String, deck: MojiWordDeck) -> [MojiWord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let catalog = catalog(deck)
        if let cached = searchCache[deck], cached.query == trimmed, cached.catalog === catalog {
            return cached.ids.compactMap { catalog.word($0) }
        }
        let ids = catalog.search.matches(trimmed)
        searchCache[deck] = (trimmed, catalog, ids)
        return ids.compactMap { catalog.word($0) }
    }

    func myCards() -> [MojiWord] {
        myQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? catalog(.mine).words
            : searchResults(myQuery, deck: .mine)
    }

    func browserWords() -> [MojiWord] {
        let deck = sheetDeck
        let base = browserQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? catalog(deck).words
            : searchResults(browserQuery, deck: deck)
        let today = snapshot(deck).today
        return base.filter { word in
            if let browserSection, word.section != browserSection {
                return false
            }
            guard browserFilter != .all else { return true }
            return allCardIDs(of: word).contains { browserFilter.matches(card($0), today: today) }
        }
    }

    func resetStudyState() {
        stage = .loading
        isFlipped = false
        typedReading = ""
        typedVerdict = nil
        flyAway = nil
        leechNotice = nil
        studyCharacter = nil
        isExitAlertPresented = false
        isBusy = false
    }
}
