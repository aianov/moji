import Foundation
import Observation

@MainActor
@Observable
final class PracticeServicesStore {
    static let shared = PracticeServicesStore()

    var presented: PracticePresentedSession?
    var stage: PracticeStage = .loading
    var isExitSheetPresented = false
    var discardCandidate: MojiPage?
    var answerModePage: MojiPage?
    var typedAnswer = ""
    var isComposingTypedAnswer = false
    var isKeyboardDismissed = false
    var hintRevision = 0
    var selectedOptionID: String?

    @ObservationIgnored var questionShownAt: Date?
    @ObservationIgnored var pendingAnswer: Task<MojiPracticeAnswerOutcome?, Never>?
    @ObservationIgnored var exitsAfterSheet = false

    private init() {}

    var snapshot: MojiPracticeRepositorySnapshot {
        MojiPracticePresentation.shared.snapshot
    }

    var activity: MojiActivitySummary {
        snapshot.activity
    }

    func session(for page: MojiPage) -> MojiPracticeSession? {
        snapshot.sessions[page]
    }

    func progress(for characterID: String) -> MojiCharacterProgress? {
        snapshot.progress[characterID]
    }

    func stats(for page: MojiPage) -> MojiPageStats {
        snapshot.pageStats[page] ?? .empty(total: MojiAlphabetCatalog.shared.pool(page).count)
    }

    func answerMode(for page: MojiPage) -> MojiAnswerMode {
        snapshot.answerMode(for: page)
    }

    var usesSameAnswerModeEverywhere: Bool {
        Set(MojiAlphabetCatalog.shared.pages.map { snapshot.answerMode(for: $0) }).count == 1
    }

    var usesSameAnswerModeInEveryTheme: Bool {
        Set(MojiAlphabetCatalog.shared.pages(.kanji).map { snapshot.answerMode(for: $0) }).count == 1
    }

    func glyphFirstKana(for page: MojiPage) -> [String] {
        let catalog = MojiAlphabetCatalog.shared
        return catalog.chart(page)
            .filter { catalog.requiresGlyphPrompt($0) }
            .map(\.glyph)
    }

    var canSubmitTypedAnswer: Bool {
        !typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func holdsKeyboard(_ model: PracticeQuestionModel) -> Bool {
        currentQuestion?.id == model.id && !isExitSheetPresented && !exitsAfterSheet && !isKeyboardDismissed
    }

    func launchState(for page: MojiPage) -> PracticeLaunchState {
        if let session = snapshot.sessions[page] {
            return .inProgress(
                answered: session.answeredCount,
                total: session.total,
                correct: session.correctCount
            )
        }
        if snapshot.activity.pagesDoneToday.contains(page) {
            return .doneToday
        }
        return .fresh
    }

    var currentQuestion: PracticeQuestionModel? {
        switch stage {
        case .question(let model), .revealed(let model, _):
            model
        case .loading, .finished, .unavailable:
            nil
        }
    }

    var currentReveal: PracticeReveal? {
        guard case .revealed(_, let reveal) = stage else { return nil }
        return reveal
    }

    func resetSessionState() {
        stage = .loading
        isExitSheetPresented = false
        typedAnswer = ""
        isComposingTypedAnswer = false
        isKeyboardDismissed = false
        selectedOptionID = nil
        questionShownAt = nil
        pendingAnswer = nil
        exitsAfterSheet = false
    }
}
