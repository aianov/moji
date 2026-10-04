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

    func setQuery(_ query: String) {
        guard service.query != query else { return }
        service.query = query
    }

    func clearQuery() {
        service.query = ""
    }

    func refreshClock() {
        actions.refreshClockAction()
    }

    func openProfile() {
        MojiHaptics.selection()
        MainTabRouter.shared.select(.profile)
    }

    func openSheet(_ sheet: WordsSheet) {
        MojiHaptics.selection()
        if sheet == .customStudy {
            if let first = service.catalog.sections.first, service.catalog.section(service.customStudy.section) == nil {
                service.customStudy.section = first.number
            }
            refreshCustomStudyCounts()
        }
        if sheet == .options {
            service.stepDraft = MojiWordStepsText.format(service.options.learningSteps)
            service.relearnStepDraft = MojiWordStepsText.format(service.options.relearningSteps)
        }
        service.sheet = sheet
    }

    func openBrowser(section: Int? = nil, filter: WordsBrowserFilter = .all) {
        service.browserSection = section
        service.browserFilter = filter
        service.browserQuery = ""
        openSheet(.browser)
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
        actions.resetAllAction()
        MojiHaptics.impact()
    }

    func cancelResetAll() {
        service.isResetAllPresented = false
    }

    func updateOptions(_ change: (inout MojiWordOptions) -> Void) {
        var options = service.options
        change(&options)
        options = options.sanitized()
        guard options != service.options else { return }
        service.optionsOverride = options
        Task {
            await actions.setOptionsAction(options)
            if service.optionsOverride == options {
                service.optionsOverride = nil
            }
        }
    }

    func commitLearningSteps() {
        guard let steps = MojiWordStepsText.parse(service.stepDraft) else {
            service.stepDraft = MojiWordStepsText.format(service.options.learningSteps)
            MojiHaptics.error()
            return
        }
        updateOptions { $0.learningSteps = steps }
        service.stepDraft = MojiWordStepsText.format(steps)
    }

    func commitRelearningSteps() {
        guard let steps = MojiWordStepsText.parse(service.relearnStepDraft) else {
            service.relearnStepDraft = MojiWordStepsText.format(service.options.relearningSteps)
            MojiHaptics.error()
            return
        }
        updateOptions { $0.relearningSteps = steps }
        service.relearnStepDraft = MojiWordStepsText.format(steps)
    }

    func restoreDefaultOptions() {
        MojiHaptics.selection()
        updateOptions { $0 = .standard }
        service.stepDraft = MojiWordStepsText.format(MojiWordOptions.standard.learningSteps)
        service.relearnStepDraft = MojiWordStepsText.format(MojiWordOptions.standard.relearningSteps)
    }

    func refreshCustomStudyCounts() {
        let draft = service.customStudy
        let scopes: [MojiWordScope] = [
            .forgotten(days: draft.forgottenDays),
            .reviewAhead(days: draft.aheadDays),
            .sectionOnly(draft.section)
        ]
        Task {
            var counts: [MojiWordScope: MojiWordQueueCounts] = [:]
            for scope in scopes {
                counts[scope] = await actions.studyCountAction(scope)
            }
            guard service.customStudy == draft else { return }
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
        Task {
            await actions.addTodayAction(extraNew: extra, extraReviews: 0)
            MojiHaptics.success()
            service.sheet = nil
        }
    }

    func addExtraReviews() {
        let extra = service.customStudy.extraReviews
        Task {
            await actions.addTodayAction(extraNew: 0, extraReviews: extra)
            MojiHaptics.success()
            service.sheet = nil
        }
    }

    func startCustomStudy(_ scope: MojiWordScope) {
        service.sheet = nil
        Task {
            try? await Task.sleep(for: Self.sheetHandoff)
            study(scope)
        }
    }

    func studySectionFromBrowser(_ section: Int) {
        startCustomStudy(.section(section))
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
