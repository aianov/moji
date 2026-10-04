import Foundation
import Observation

@MainActor
@Observable
final class PracticeInteractionsStore {
    static let shared = PracticeInteractionsStore()

    private static let maxTypedLength = 24

    private var actions: PracticeActionsStore { .shared }
    private var service: PracticeServicesStore { .shared }
    private var preferences: MojiPreferencesStore { .shared }

    private init() {}

    func openPractice(_ page: MojiPage) {
        guard service.presented == nil else { return }
        service.resetSessionState()
        service.presented = PracticePresentedSession(page: page)
        MojiHaptics.impact()

        Task {
            let session = await actions.startSessionAction(page)
            guard service.presented?.page == page, service.stage == .loading else { return }
            guard let session,
                  let model = PracticeQuestionModel.make(session: session, catalog: .shared) else {
                service.stage = .unavailable
                return
            }
            show(model)
        }
    }

    func select(_ optionID: String) {
        guard case .question(let model) = service.stage, !model.isTyped,
              service.selectedOptionID != optionID else { return }
        MojiHaptics.selection()
        service.selectedOptionID = optionID
    }

    func check() {
        guard case .question(let model) = service.stage else { return }
        if model.isTyped {
            checkTypedAnswer()
            return
        }
        guard let chosen = service.selectedOptionID else { return }
        reveal(chosenID: chosen, typed: nil)
    }

    func dontKnow() {
        reveal(chosenID: nil, typed: nil)
    }

    func speakPrompt() {
        guard let model = service.currentQuestion else { return }
        MojiSpeech.shared.speak(model.answer)
    }

    func speak(_ character: MojiCharacter) {
        MojiSpeech.shared.speak(character)
    }

    func editTypedAnswer(_ text: String, isComposing: Bool) {
        guard case .question(let model) = service.stage, model.isTyped else { return }
        let kept = isComposing ? text : String(text.prefix(Self.maxTypedLength))
        if service.typedAnswer != kept {
            service.typedAnswer = kept
        }
        if service.isComposingTypedAnswer != isComposing {
            service.isComposingTypedAnswer = isComposing
        }
    }

    func checkTypedAnswer() {
        guard case .question(let model) = service.stage, model.isTyped,
              service.canSubmitTypedAnswer else {
            return
        }
        reveal(chosenID: nil, typed: service.typedAnswer)
    }

    func useHint() {
        guard case .question(let model) = service.stage, model.isTyped else { return }
        service.typedAnswer = model.hintText
        service.isComposingTypedAnswer = false
        service.hintRevision += 1
    }

    func dismissKeyboard() {
        guard service.currentQuestion?.isTyped == true, !service.isKeyboardDismissed else { return }
        service.isKeyboardDismissed = true
    }

    func focusAnswerField() {
        guard service.isKeyboardDismissed else { return }
        service.isKeyboardDismissed = false
    }

    func keyboardReturn() {
        switch service.stage {
        case .question:
            checkTypedAnswer()
        case .revealed:
            continueAfterReveal()
        case .loading, .finished, .unavailable:
            break
        }
    }

    func continueAfterReveal() {
        guard case .revealed(let model, _) = service.stage else { return }
        let pending = service.pendingAnswer

        Task {
            var outcome: MojiPracticeAnswerOutcome?
            if let pending {
                outcome = await pending.value
            }
            guard case .revealed(let current, _) = service.stage, current.id == model.id else { return }
            service.pendingAnswer = nil

            switch outcome {
            case .next(let session)?:
                if let next = PracticeQuestionModel.make(session: session, catalog: .shared) {
                    show(next)
                } else {
                    showFromSnapshot(page: model.page)
                }
            case .completed(let completion)?:
                service.stage = .finished(
                    PracticeSummaryModel.make(completion: completion, catalog: .shared)
                )
                MojiHaptics.success()
            case nil:
                showFromSnapshot(page: model.page)
            }
        }
    }

    func close() {
        switch service.stage {
        case .question, .revealed:
            MojiHaptics.selection()
            service.isExitSheetPresented = true
        case .loading, .finished, .unavailable:
            dismiss()
        }
    }

    func keepPracticing() {
        service.isExitSheetPresented = false
    }

    func saveAndExit() {
        service.exitsAfterSheet = true
        service.isExitSheetPresented = false
    }

    func discardAndExit() {
        guard let page = service.presented?.page else { return }
        actions.discardSessionAction(page)
        service.exitsAfterSheet = true
        service.isExitSheetPresented = false
    }

    func exitSheetDidDismiss() {
        guard service.exitsAfterSheet else { return }
        service.exitsAfterSheet = false
        dismiss()
    }

    func finish() {
        dismiss()
    }

    func didDismiss() {
        MojiSpeech.shared.stop()
        service.resetSessionState()
    }

    func requestDiscard(_ page: MojiPage) {
        MojiHaptics.selection()
        service.discardCandidate = page
    }

    func confirmDiscard() {
        guard let page = service.discardCandidate else { return }
        service.discardCandidate = nil
        actions.discardSessionAction(page)
        MojiHaptics.impact()
    }

    func cancelDiscard() {
        service.discardCandidate = nil
    }

    func openAnswerMode(_ page: MojiPage) {
        MojiHaptics.selection()
        service.answerModePage = page
    }

    func closeAnswerMode() {
        service.answerModePage = nil
    }

    func setAnswerInput(_ input: MojiAnswerInput, for page: MojiPage) {
        guard service.answerMode(for: page).input != input else { return }
        MojiHaptics.selection()
        actions.setAnswerInputAction(input, page: page)
    }

    func setAnswerSide(_ side: MojiAnswerSide, for page: MojiPage) {
        guard service.answerMode(for: page).side != side else { return }
        MojiHaptics.selection()
        actions.setAnswerSideAction(side, page: page)
    }

    func useAnswerModeEverywhere(from page: MojiPage) {
        MojiHaptics.impact()
        actions.copyAnswerModeAction(from: page, to: MojiAlphabetCatalog.shared.pages)
    }

    func useAnswerModeInEveryTheme(from page: MojiPage) {
        MojiHaptics.impact()
        actions.copyAnswerModeAction(from: page, to: MojiAlphabetCatalog.shared.pages(.kanji))
    }

    private func reveal(chosenID: String?, typed: String?) {
        guard case .question(let model) = service.stage else { return }
        let isCorrect = typed.map { model.accepts($0) } ?? (chosenID == model.correctOptionID)
        let now = Date()

        service.stage = .revealed(
            model,
            PracticeReveal(chosenID: chosenID, isCorrect: isCorrect, typed: typed)
        )
        if isCorrect {
            MojiHaptics.success()
        } else {
            MojiHaptics.error()
        }
        if preferences.speaksCharacters {
            MojiSpeech.shared.speak(model.answer)
        }

        let submission = MojiAnswerSubmission(
            page: model.page,
            sessionID: model.sessionID,
            questionIndex: model.index,
            chosenID: chosenID,
            thinkSeconds: service.questionShownAt.map { now.timeIntervalSince($0) } ?? 0,
            answeredAt: now,
            typed: typed
        )
        let actions = actions
        service.pendingAnswer = Task {
            await actions.answerAction(submission)
        }
    }

    private func show(_ model: PracticeQuestionModel) {
        service.typedAnswer = ""
        service.isComposingTypedAnswer = false
        service.isKeyboardDismissed = false
        service.selectedOptionID = nil
        service.stage = .question(model)
        service.questionShownAt = Date()
    }

    private func showFromSnapshot(page: MojiPage) {
        guard let session = service.session(for: page),
              let model = PracticeQuestionModel.make(session: session, catalog: .shared) else {
            dismiss()
            return
        }
        show(model)
    }

    private func dismiss() {
        service.isExitSheetPresented = false
        service.presented = nil
    }
}
