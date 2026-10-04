import Foundation
import Observation

@MainActor
@Observable
final class WordsServicesStore {
    static let shared = WordsServicesStore()

    var query = ""
    var sheet: WordsSheet?
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
    var optionsOverride: MojiWordOptions?
    var stepDraft = ""
    var relearnStepDraft = ""
    var dueDraft = 1

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
    @ObservationIgnored private var searchCache: (query: String, catalog: MojiWordCatalog, ids: [String])?

    private init() {}

    var snapshot: MojiWordRepositorySnapshot {
        MojiWordPresentation.shared.snapshot
    }

    var catalog: MojiWordCatalog {
        snapshot.catalog
    }

    var options: MojiWordOptions {
        optionsOverride ?? snapshot.options
    }

    var isLoaded: Bool {
        snapshot.isLoaded
    }

    var activity: MojiActivitySummary {
        MojiPracticePresentation.shared.snapshot.activity
    }

    var currentCard: MojiWordStudyCard? {
        guard case .card(let card) = stage else { return nil }
        return card
    }

    var detailWord: MojiWord? {
        detail.flatMap { catalog.word($0.wordID) }
    }

    func card(_ id: MojiWordCardID) -> MojiWordCard {
        snapshot.card(id)
    }

    func cardIDs(of word: MojiWord) -> [MojiWordCardID] {
        MojiWordStats.cardIDs(of: word, options: options)
    }

    func allCardIDs(of word: MojiWord) -> [MojiWordCardID] {
        let ids = cardIDs(of: word)
        let reverse = MojiWordCardID(wordID: word.id, kind: .recall)
        if !ids.contains(reverse), snapshot.cards[reverse.key] != nil {
            return ids + [reverse]
        }
        return ids
    }

    func state(of word: MojiWord) -> MojiWordCardState {
        MojiWordCardState.of(card(MojiWordCardID(wordID: word.id)), today: snapshot.today)
    }

    func sectionStats(_ section: MojiWordSection) -> MojiWordSectionStats {
        snapshot.sections[section.number] ?? MojiWordSectionStats(number: section.number)
    }

    func note(for word: MojiWord) -> String? {
        snapshot.notes[word.id]
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

    func searchResults(_ query: String) -> [MojiWord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if let searchCache, searchCache.query == trimmed, searchCache.catalog === catalog {
            return searchCache.ids.compactMap { catalog.word($0) }
        }
        let ids = catalog.search.matches(trimmed)
        searchCache = (trimmed, catalog, ids)
        return ids.compactMap { catalog.word($0) }
    }

    func browserWords() -> [MojiWord] {
        let base = browserQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? catalog.words
            : searchResults(browserQuery)
        let today = snapshot.today
        return base.filter { word in
            if let browserSection, word.section != browserSection {
                return false
            }
            guard browserFilter != .all else { return true }
            return allCardIDs(of: word).contains { browserFilter.matches(card($0), today: today) }
        }
    }

    var studiedToday: MojiWordDayStats {
        snapshot.todayStats
    }

    var canStudy: Bool {
        isLoaded && (snapshot.queue.total > 0 || snapshot.nextLearningAt != nil)
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
