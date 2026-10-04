import Foundation

extension WordsInteractionsStore {
    func newCard(from origin: WordsCardOrigin = .page) {
        MojiHaptics.selection()
        service.draft = WordsCardDraft()
        service.isDiscardCardPresented = false
        service.editor = WordsCardEditor(wordID: nil, origin: origin, token: UUID())
    }

    func editCard(_ word: MojiWord, from origin: WordsCardOrigin) {
        guard MojiWordDeck.of(wordID: word.id) == .mine else { return }
        MojiHaptics.selection()
        service.draft = makeDraft(for: word)
        service.isDiscardCardPresented = false
        service.editor = WordsCardEditor(wordID: word.id, origin: origin, token: UUID())
    }

    func closeCardEditor() {
        service.isDiscardCardPresented = false
        service.editor = nil
    }

    func cancelCard() {
        guard service.draft.hasChanges else {
            closeCardEditor()
            return
        }
        MojiHaptics.selection()
        service.isDiscardCardPresented = true
    }

    func discardCard() {
        closeCardEditor()
    }

    func keepEditingCard() {
        service.isDiscardCardPresented = false
    }

    func setCardWord(_ text: String) {
        guard service.draft.word != text else { return }
        service.draft.word = text
        let auto = MojiWordReadings.reading(of: text, dictionary: service.readingDictionary)
        service.draft.autoReading = auto
        if !service.draft.isReadingEdited {
            service.draft.reading = auto
        }
        service.draft.tokens = MojiWordReadings.markingTarget(service.draft.tokens, word: text)
    }

    func setCardReading(_ text: String) {
        guard service.draft.reading != text else { return }
        service.draft.reading = text
        service.draft.isReadingEdited = !text.isEmpty && text != service.draft.autoReading
    }

    func commitCardReading() {
        let normalized = MojiWordReadings.normalized(service.draft.reading)
        guard normalized != service.draft.reading else { return }
        setCardReading(normalized)
    }

    func restoreCardReading() {
        MojiHaptics.selection()
        service.draft.reading = service.draft.autoReading
        service.draft.isReadingEdited = false
    }

    func setCardMeaning(_ text: String) {
        guard service.draft.meaning != text else { return }
        service.draft.meaning = text
    }

    func setCardSentence(_ text: String) {
        guard service.draft.sentence != text else { return }
        service.draft.sentence = text
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        service.draft.autoTokens = MojiWordReadings.tokens(of: trimmed, dictionary: service.readingDictionary)
        applyCardFixes()
    }

    func setCardTranslation(_ text: String) {
        guard service.draft.translation != text else { return }
        service.draft.translation = text
    }

    func setCardNote(_ text: String) {
        guard service.draft.note != text else { return }
        service.draft.note = text
    }

    func setTokenReading(_ text: String, for surface: String) {
        guard service.draft.fixes[surface] != text else { return }
        service.draft.fixes[surface] = text
        applyCardFixes()
    }

    func commitTokenReading(for surface: String) {
        guard let fix = service.draft.fixes[surface] else { return }
        let normalized = MojiWordReadings.normalized(fix)
        let auto = service.draft.autoReading(of: surface) ?? ""
        service.draft.fixes[surface] = normalized.isEmpty || normalized == auto ? nil : normalized
        applyCardFixes()
    }

    func restoreTokenReading(for surface: String) {
        MojiHaptics.selection()
        service.draft.fixes[surface] = nil
        applyCardFixes()
    }

    func saveCard(addAnother: Bool) {
        guard let editor = service.editor, !service.isSavingCard else { return }
        commitCardReading()
        for surface in Array(service.draft.fixes.keys) {
            commitTokenReading(for: surface)
        }
        let draft = service.draft
        guard draft.problems.isEmpty else {
            MojiHaptics.error()
            return
        }
        let input = draft.input
        let keepsOpen = addAnother && editor.isNew
        service.isSavingCard = true
        if keepsOpen {
            var next = WordsCardDraft()
            next.lastAdded = input.cleaned().written
            service.draft = next
            service.cardFocusToken += 1
        }

        Task {
            let saved: MojiOwnWord?
            if let wordID = editor.wordID {
                saved = await actions.updateOwnWordAction(wordID, input: input)
            } else {
                saved = await actions.addOwnWordAction(input)
            }
            service.isSavingCard = false
            let isSameEditor = service.editor?.token == editor.token
            guard saved != nil else {
                MojiHaptics.error()
                if keepsOpen, isSameEditor, service.draft.isEmpty {
                    service.draft = draft
                }
                return
            }
            MojiHaptics.success()
            if !keepsOpen, isSameEditor {
                closeCardEditor()
            }
        }
    }

    func requestDeleteCard(_ word: MojiWord, from origin: WordsCardOrigin) {
        guard MojiWordDeck.of(wordID: word.id) == .mine else { return }
        MojiHaptics.selection()
        service.deleteRequest = WordsDeleteRequest(wordID: word.id, written: word.written, origin: origin)
    }

    func confirmDeleteCard() {
        guard let request = service.deleteRequest else { return }
        service.deleteRequest = nil
        actions.deleteOwnWordsAction([request.wordID])
        service.histories[request.wordID] = nil
        if service.detail?.wordID == request.wordID {
            service.detail = nil
        }
        MojiHaptics.impact()
    }

    func cancelDeleteCard() {
        service.deleteRequest = nil
    }

    private func applyCardFixes() {
        let draft = service.draft
        let tokens = draft.autoTokens.map { token -> MojiWordToken in
            guard token.hasKanji,
                  let fix = draft.fixes[token.surface]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !fix.isEmpty else { return token }
            return MojiWordToken(surface: token.surface, reading: fix)
        }
        service.draft.tokens = MojiWordReadings.markingTarget(tokens, word: draft.word)
    }

    private func makeDraft(for word: MojiWord) -> WordsCardDraft {
        let dictionary = service.readingDictionary
        let sentence = word.sentences.first
        let tokens = sentence?.tokens ?? []
        let text = tokens.map(\.surface).joined()
        let autoTokens = MojiWordReadings.tokens(of: text, dictionary: dictionary)
        var fixes: [String: String] = [:]
        for token in tokens where token.hasKanji {
            guard let reading = token.reading,
                  autoTokens.first(where: { $0.surface == token.surface })?.reading != reading else { continue }
            fixes[token.surface] = reading
        }
        let autoReading = MojiWordReadings.reading(of: word.written, dictionary: dictionary)

        var draft = WordsCardDraft()
        draft.word = word.written
        draft.reading = word.reading
        draft.autoReading = autoReading
        draft.isReadingEdited = !word.reading.isEmpty && word.reading != autoReading
        draft.meaning = word.english
        draft.sentence = text
        draft.autoTokens = autoTokens
        draft.tokens = tokens
        draft.fixes = fixes
        draft.translation = sentence?.english ?? ""
        draft.note = service.note(for: word) ?? ""
        draft.original = draft.input
        return draft
    }
}
