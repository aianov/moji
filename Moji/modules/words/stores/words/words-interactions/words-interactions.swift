import Foundation
import Observation

@MainActor
@Observable
final class WordsInteractionsStore {
    static let shared = WordsInteractionsStore()

    static let sheetHandoff: Duration = .milliseconds(450)

    var actions: WordsActionsStore { .shared }
    var service: WordsServicesStore { .shared }
    var speech: MojiWordSpeech { .shared }

    private init() {}

    func selectDeck(_ deck: MojiWordDeck) {
        guard service.selectedDeck != deck else { return }
        service.selectedDeck = deck
        UserDefaults.standard.set(deck.rawValue, forKey: WordsServicesStore.deckKey)
    }

    func setQuery(_ query: String) {
        guard service.query != query else { return }
        service.query = query
    }

    func clearQuery() {
        service.query = ""
    }

    func setMyQuery(_ query: String) {
        guard service.myQuery != query else { return }
        service.myQuery = query
    }

    func refreshClock() {
        actions.refreshClockAction()
    }

    func syncAfterReload() {
        service.reloadFromDefaults()
        service.histories = [:]
        service.optionsOverrides = [:]
        service.customStudyCounts = [:]
        if let detail = service.detail, service.word(detail.wordID) == nil {
            service.detail = nil
        }
        if let wordID = service.editor?.wordID, service.word(wordID) == nil {
            closeCardEditor()
        }
        if let request = service.deleteRequest, service.word(request.wordID) == nil {
            service.deleteRequest = nil
        }
    }

    func openProfile() {
        MojiHaptics.selection()
        MainTabRouter.shared.select(.profile)
    }

    func openSheet(_ sheet: WordsSheet, deck: MojiWordDeck) {
        MojiHaptics.selection()
        service.sheetDeck = deck
        if sheet == .customStudy {
            let catalog = service.catalog(deck)
            if let first = catalog.sections.first, catalog.section(service.customStudy.section) == nil {
                service.customStudy.section = first.number
            }
            service.customStudyCounts = [:]
            refreshCustomStudyCounts()
        }
        if sheet == .options {
            let options = service.options(deck)
            service.stepDraft = MojiWordStepsText.format(options.learningSteps)
            service.relearnStepDraft = MojiWordStepsText.format(options.relearningSteps)
        }
        service.sheet = sheet
    }

    func openBrowser(deck: MojiWordDeck, section: Int? = nil, filter: WordsBrowserFilter = .all) {
        service.browserSection = deck == .frequent ? section : nil
        service.browserFilter = filter
        service.browserQuery = ""
        openSheet(.browser, deck: deck)
    }

    func closeSheet() {
        service.sheet = nil
    }

    func setBrowserQuery(_ query: String) {
        service.browserQuery = query
    }

    func setBrowserFilter(_ filter: WordsBrowserFilter) {
        guard service.browserFilter != filter else { return }
        service.browserFilter = filter
        MojiHaptics.selection()
    }

    func setBrowserSection(_ section: Int?) {
        guard service.browserSection != section else { return }
        service.browserSection = section
        MojiHaptics.selection()
    }

    func openWord(_ word: MojiWord) {
        MojiHaptics.selection()
        service.dueDraft = 1
        service.detail = WordsDetailTarget(wordID: word.id)
    }

    func closeWord() {
        service.detail = nil
    }

    func loadHistory(_ word: MojiWord) {
        let wordID = word.id
        Task {
            let history = await actions.historyAction(wordID)
            service.histories[wordID] = history
        }
    }

    func openCharacter(_ character: MojiCharacter) {
        speech.stop()
        MojiHaptics.selection()
        service.detailCharacter = character
    }

    func closeCharacter() {
        service.detailCharacter = nil
    }

    func playWord(_ word: MojiWord) {
        speech.play(MojiWordVoice.wordItems(word))
    }

    func playSentence(_ sentence: MojiWordSentence) {
        speech.play(MojiWordVoice.sentenceItems(sentence, allowSynthesis: true))
    }

    func requestSectionAction(_ kind: WordsSectionActionKind, section: MojiWordSection) {
        MojiHaptics.selection()
        service.sectionAction = WordsSectionAction(kind: kind, section: section)
    }

    func confirmSectionAction() {
        guard let action = service.sectionAction else { return }
        service.sectionAction = nil
        switch action.kind {
        case .known:
            actions.markKnownAction(action.section.wordIDs)
            MojiHaptics.success()
        case .reset:
            actions.forgetAction(action.section.wordIDs)
            MojiHaptics.impact()
        }
    }

    func cancelSectionAction() {
        service.sectionAction = nil
    }

    func requestResetAll() {
        MojiHaptics.selection()
        service.isResetAllPresented = true
    }

    func confirmResetAll() {
        service.isResetAllPresented = false
        actions.resetDeckAction(service.sheetDeck)
        MojiHaptics.impact()
    }

    func cancelResetAll() {
        service.isResetAllPresented = false
    }

    func updateOptions(deck: MojiWordDeck, _ change: (inout MojiWordOptions) -> Void) {
        let current = service.options(deck)
        var options = current
        change(&options)
        options = options.sanitized()
        guard options != current else { return }
        service.optionsOverrides[deck] = options
        Task {
            await actions.setOptionsAction(options, deck: deck)
            if service.optionsOverrides[deck] == options {
                service.optionsOverrides[deck] = nil
            }
        }
    }

    func commitLearningSteps() {
        let deck = service.sheetDeck
        guard let steps = MojiWordStepsText.parse(service.stepDraft) else {
            service.stepDraft = MojiWordStepsText.format(service.options(deck).learningSteps)
            MojiHaptics.error()
            return
        }
        updateOptions(deck: deck) { $0.learningSteps = steps }
        service.stepDraft = MojiWordStepsText.format(steps)
    }

    func commitRelearningSteps() {
        let deck = service.sheetDeck
        guard let steps = MojiWordStepsText.parse(service.relearnStepDraft) else {
            service.relearnStepDraft = MojiWordStepsText.format(service.options(deck).relearningSteps)
            MojiHaptics.error()
            return
        }
        updateOptions(deck: deck) { $0.relearningSteps = steps }
        service.relearnStepDraft = MojiWordStepsText.format(steps)
    }

    func restoreDefaultOptions() {
        MojiHaptics.selection()
        updateOptions(deck: service.sheetDeck) { $0 = .standard }
        service.stepDraft = MojiWordStepsText.format(MojiWordOptions.standard.learningSteps)
        service.relearnStepDraft = MojiWordStepsText.format(MojiWordOptions.standard.relearningSteps)
    }

    func refreshCustomStudyCounts() {
        let deck = service.sheetDeck
        let draft = service.customStudy
        var scopes: [MojiWordScope] = [
            .forgotten(days: draft.forgottenDays),
            .reviewAhead(days: draft.aheadDays)
        ]
        if deck == .frequent {
            scopes.append(.sectionOnly(draft.section))
        }
        Task {
            var counts: [MojiWordScope: MojiWordQueueCounts] = [:]
            for scope in scopes {
                counts[scope] = await actions.studyCountAction(scope, deck: deck)
            }
            guard service.customStudy == draft, service.sheetDeck == deck else { return }
            service.customStudyCounts = counts
        }
    }

    func updateCustomStudy(_ change: (inout WordsCustomStudyDraft) -> Void) {
        var draft = service.customStudy
        change(&draft)
        guard draft != service.customStudy else { return }
        service.customStudy = draft
        refreshCustomStudyCounts()
    }

    func addExtraNew() {
        let extra = service.customStudy.extraNew
        let deck = service.sheetDeck
        Task {
            await actions.addTodayAction(extraNew: extra, extraReviews: 0, deck: deck)
            MojiHaptics.success()
            service.sheet = nil
        }
    }

    func addExtraReviews() {
        let extra = service.customStudy.extraReviews
        let deck = service.sheetDeck
        Task {
            await actions.addTodayAction(extraNew: 0, extraReviews: extra, deck: deck)
            MojiHaptics.success()
            service.sheet = nil
        }
    }

    func startCustomStudy(_ scope: MojiWordScope, deck: MojiWordDeck) {
        service.sheet = nil
        Task {
            try? await Task.sleep(for: Self.sheetHandoff)
            study(scope, deck: deck)
        }
    }

    func studySectionFromBrowser(_ section: Int) {
        startCustomStudy(.section(section), deck: .frequent)
    }

    func setSuspended(_ suspended: Bool, cards: [MojiWordCardID]) {
        MojiHaptics.selection()
        actions.setSuspendedAction(suspended, cards: cards)
    }

    func bury(_ cards: [MojiWordCardID]) {
        MojiHaptics.selection()
        actions.buryAction(cards)
    }

    func unbury(_ cards: [MojiWordCardID]) {
        MojiHaptics.selection()
        actions.unburyAction(cards)
    }

    func forget(_ word: MojiWord) {
        MojiHaptics.impact()
        actions.forgetAction([word.id])
        reloadHistorySoon(word)
    }

    func markKnown(_ word: MojiWord) {
        MojiHaptics.success()
        actions.markKnownAction([word.id])
        reloadHistorySoon(word)
    }

    func setDueDraft(_ days: Int) {
        service.dueDraft = min(3_650, max(0, days))
    }

    func reschedule(_ cards: [MojiWordCardID], word: MojiWord) {
        MojiHaptics.selection()
        actions.rescheduleAction(cards, inDays: service.dueDraft)
        reloadHistorySoon(word)
    }

    func setFlag(_ flag: MojiWordFlag?, cards: [MojiWordCardID]) {
        MojiHaptics.selection()
        actions.setFlagAction(flag, cards: cards)
    }

    func setLeech(_ isLeech: Bool, cards: [MojiWordCardID]) {
        MojiHaptics.selection()
        actions.setLeechAction(isLeech, cards: cards)
    }

    func setNote(_ note: String, for word: MojiWord) {
        actions.setNoteAction(note, wordID: word.id)
    }

    private func reloadHistorySoon(_ word: MojiWord) {
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            loadHistory(word)
        }
    }
}
