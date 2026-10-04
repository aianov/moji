import Foundation
import Observation

@MainActor
@Observable
final class WordsActionsStore {
    static let shared = WordsActionsStore()

    private init() {}

    private func repository() async -> MojiWordRepository {
        await MojiWordDomainRegistry.shared.requireDomain().repository
    }

    func startSessionAction(_ scope: MojiWordScope) async -> MojiWordStudyStep {
        await repository().startSession(scope, now: Date())
    }

    func answerAction(_ id: MojiWordCardID, button: MojiWordButton, seconds: Double) async -> MojiWordStudyStep? {
        await repository().answer(id, button: button, seconds: seconds, now: Date())
    }

    func undoAction() async -> MojiWordStudyStep? {
        await repository().undo(now: Date())
    }

    func stepAction() async -> MojiWordStudyStep? {
        await repository().step(now: Date())
    }

    func endSessionAction() async -> MojiWordSessionSummary? {
        await repository().endSession(now: Date())
    }

    func recordActivityAction(_ summary: MojiWordSessionSummary) async -> (streak: Int, extendedStreak: Bool)? {
        guard summary.isComplete, summary.answered > 0 else { return nil }
        let domain = await MojiPracticeDomainRegistry.shared.requireDomain()
        let result = await domain.repository.recordWordsSession(
            total: summary.answered,
            correct: summary.correct,
            startedAt: summary.startedAt,
            activeSeconds: summary.seconds,
            at: summary.finishedAt
        )
        return (result.streak, result.extendedStreak)
    }

    func setOptionsAction(_ options: MojiWordOptions) async {
        await repository().setOptions(options, now: Date())
    }

    func addTodayAction(extraNew: Int, extraReviews: Int) async {
        await repository().addToday(extraNew: extraNew, extraReviews: extraReviews, now: Date())
    }

    func studyCountAction(_ scope: MojiWordScope) async -> MojiWordQueueCounts {
        await repository().studyCount(for: scope, now: Date())
    }

    func markKnownAction(_ wordIDs: [String]) {
        Task {
            await repository().markKnown(wordIDs: wordIDs, now: Date())
        }
    }

    func forgetAction(_ wordIDs: [String]) {
        Task {
            await repository().forget(wordIDs: wordIDs, now: Date())
        }
    }

    func setSuspendedAction(_ suspended: Bool, cards: [MojiWordCardID]) {
        Task {
            await repository().setSuspended(suspended, cards: cards, now: Date())
        }
    }

    func buryAction(_ cards: [MojiWordCardID]) {
        Task {
            await repository().bury(cards, now: Date())
        }
    }

    func unburyAction(_ cards: [MojiWordCardID]) {
        Task {
            await repository().unbury(cards, now: Date())
        }
    }

    func rescheduleAction(_ cards: [MojiWordCardID], inDays days: Int) {
        Task {
            await repository().reschedule(cards, inDays: days, now: Date())
        }
    }

    func setFlagAction(_ flag: MojiWordFlag?, cards: [MojiWordCardID]) {
        Task {
            await repository().setFlag(flag, cards: cards, now: Date())
        }
    }

    func setLeechAction(_ isLeech: Bool, cards: [MojiWordCardID]) {
        Task {
            await repository().setLeech(isLeech, cards: cards, now: Date())
        }
    }

    func setNoteAction(_ note: String, wordID: String) {
        Task {
            await repository().setNote(note, wordID: wordID, now: Date())
        }
    }

    func historyAction(_ wordID: String) async -> [MojiWordCardID: [MojiWordReview]] {
        await repository().history(wordID: wordID)
    }

    func resetAllAction() {
        Task {
            await repository().resetAll(now: Date())
        }
    }

    func refreshClockAction() {
        Task {
            await repository().refreshClock(now: Date())
        }
    }
}
