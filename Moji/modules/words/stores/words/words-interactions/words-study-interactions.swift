import SwiftUI

extension WordsInteractionsStore {
    static let flipAnimation = Animation.spring(response: 0.5, dampingFraction: 0.82)
    static let dealAnimation = Animation.spring(response: 0.44, dampingFraction: 0.84)
    static let flightLead: Duration = .milliseconds(24)
    static let leechNoticeTime: Duration = .seconds(3)
    static let pauseBeforeSentence = 0.35

    func study(_ scope: MojiWordScope = .deck, deck: MojiWordDeck) {
        guard service.presented == nil, service.isLoaded(deck) else { return }
        speech.stop()
        service.resetStudyState()
        let token = UUID()
        service.presented = WordsPresentedStudy(scope: scope, deck: deck, token: token)
        WordsHaptics.prepare()
        MojiHaptics.impact()

        Task {
            let step = await actions.startSessionAction(scope, deck: deck)
            guard service.presented?.token == token else { return }
            await apply(step)
        }
    }

    func studySection(_ section: MojiWordSection) {
        study(.section(section.number), deck: .frequent)
    }

    func setTypedReading(_ text: String) {
        guard !service.isFlipped else { return }
        service.typedReading = text
    }

    func showAnswer() {
        guard let card = service.currentCard, !service.isFlipped, !service.isBusy else { return }
        let options = service.options(service.studyDeck)
        if options.typeReading {
            service.typedVerdict = verdict(for: service.typedReading, word: card.word)
        }
        withAnimation(Self.flipAnimation) {
            service.isFlipped = true
        }
        WordsHaptics.flip()
        if options.autoplayAudio {
            playAnswer(card)
        }
    }

    func grade(_ button: MojiWordButton) {
        guard let card = service.currentCard, service.isFlipped, !service.isBusy else { return }
        let deck = service.studyDeck
        service.isBusy = true
        let seconds = Date().timeIntervalSince(service.cardShownAt)
        let wasLeech = card.card.isLeech
        service.flyCount += 1
        service.flyAway = WordsFlyAway(button: button, token: service.flyCount)
        WordsHaptics.grade(button)
        speech.stop()

        Task {
            try? await Task.sleep(for: Self.flightLead)
            let next = await actions.answerAction(card.id, button: button, seconds: seconds, deck: deck)
            guard service.currentCard?.id == card.id, let next else {
                service.isBusy = false
                return
            }
            let after = service.snapshot(deck).card(card.id)
            if !card.isCram, after.isLeech, !wasLeech || (button == .again && after.isSuspended) {
                showLeechNotice(card.word, suspended: after.isSuspended)
            }
            await apply(next)
        }
    }

    func undo() {
        guard case .card(let card) = service.stage, card.canUndo, !service.isBusy else { return }
        let deck = service.studyDeck
        service.isBusy = true
        speech.stop()
        service.flyAway = nil
        Task {
            try? await Task.sleep(for: Self.flightLead)
            guard let step = await actions.undoAction(deck: deck) else {
                service.isBusy = false
                return
            }
            MojiHaptics.selection()
            await apply(step)
        }
    }

    func replayWord() {
        guard let card = service.currentCard else { return }
        playWord(card.word)
    }

    func replaySentence() {
        guard let sentence = service.currentCard?.sentence else { return }
        playSentence(sentence)
    }

    func swipeCrossedThreshold() {
        MojiHaptics.selection()
    }

    func openStudyCharacter(_ character: MojiCharacter) {
        speech.stop()
        MojiHaptics.selection()
        service.studyCharacter = character
    }

    func closeStudyCharacter() {
        service.studyCharacter = nil
    }

    func close() {
        let deck = service.studyDeck
        switch service.stage {
        case .card(let card) where card.answered > 0:
            MojiHaptics.selection()
            service.isExitAlertPresented = true
        case .card, .loading:
            Task {
                _ = await actions.endSessionAction(deck: deck)
                dismissStudy()
            }
        case .finished:
            dismissStudy()
        }
    }

    func keepStudying() {
        service.isExitAlertPresented = false
    }

    func stopStudying() {
        let deck = service.studyDeck
        service.isExitAlertPresented = false
        Task {
            _ = await actions.endSessionAction(deck: deck)
            dismissStudy()
        }
    }

    func finishStudy() {
        dismissStudy()
    }

    func openCustomStudyAfterSession() {
        let deck = service.studyDeck
        dismissStudy()
        Task {
            try? await Task.sleep(for: Self.sheetHandoff)
            openSheet(.customStudy, deck: deck)
        }
    }

    func studyDidDismiss() {
        speech.stop()
        service.resetStudyState()
        refreshClock()
    }

    private func dismissStudy() {
        speech.stop()
        service.isExitAlertPresented = false
        service.presented = nil
    }

    private func apply(_ step: MojiWordStudyStep) async {
        switch step {
        case .card(let card):
            withAnimation(Self.dealAnimation) {
                service.isFlipped = false
                service.typedReading = ""
                service.typedVerdict = nil
                service.stage = .card(card)
            }
            service.cardShownAt = Date()
            service.isBusy = false
        case .finished(let summary):
            service.isBusy = true
            let record = await actions.recordActivityAction(summary)
            withAnimation(Self.dealAnimation) {
                service.stage = .finished(
                    WordsStudySummaryModel(
                        summary: summary,
                        streak: record?.streak,
                        extendedStreak: record?.extendedStreak ?? false
                    )
                )
            }
            service.isBusy = false
            if summary.isComplete, summary.answered > 0 {
                MojiHaptics.success()
            }
        }
    }

    private func playAnswer(_ card: MojiWordStudyCard) {
        var items = MojiWordVoice.wordItems(card.word)
        if let sentence = card.sentence {
            let clip = MojiWordVoice.sentenceItems(sentence, allowSynthesis: false)
            if !clip.isEmpty {
                items.append(.pause(Self.pauseBeforeSentence))
                items += clip
            }
        }
        speech.play(items)
    }

    private func verdict(for typed: String, word: MojiWord) -> WordsTypedVerdict {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .skipped }
        let written = trimmed.precomposedStringWithCanonicalMapping
        if MojiWordRomaji.hiragana(written) == MojiWordRomaji.hiragana(word.reading)
            || written == word.written
            || MojiRomaji.matches(written, kana: word.reading) {
            return .right
        }
        return .wrong(typed: trimmed)
    }

    private func showLeechNotice(_ word: MojiWord, suspended: Bool) {
        let notice = WordsLeechNotice(word: word.written, suspended: suspended, token: UUID())
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            service.leechNotice = notice
        }
        Task {
            try? await Task.sleep(for: Self.leechNoticeTime)
            guard service.leechNotice?.token == notice.token else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                service.leechNotice = nil
            }
        }
    }
}
