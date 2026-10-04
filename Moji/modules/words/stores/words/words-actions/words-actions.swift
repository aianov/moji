import Foundation
import Observation

@MainActor
@Observable
final class WordsActionsStore {
    static let shared = WordsActionsStore()

    private init() {}

    private func domain() async -> MojiWordDomain {
        await MojiWordDomainRegistry.shared.requireDomain()
    }

    private func repository(_ deck: MojiWordDeck) async -> MojiWordRepository {
        await domain().repository(for: deck)
    }

    private func wordIDsByDeck(_ wordIDs: [String]) -> [MojiWordDeck: [String]] {
        Dictionary(grouping: wordIDs) { MojiWordDeck.of(wordID: $0) }
    }

    private func cardsByDeck(_ cards: [MojiWordCardID]) -> [MojiWordDeck: [MojiWordCardID]] {
        Dictionary(grouping: cards) { MojiWordDeck.of(wordID: $0.wordID) }
    }

    func startSessionAction(_ scope: MojiWordScope, deck: MojiWordDeck) async -> MojiWordStudyStep {
        await repository(deck).startSession(scope, now: Date())
    }

    func answerAction(_ id: MojiWordCardID, button: MojiWordButton, seconds: Double, deck: MojiWordDeck) async -> MojiWordStudyStep? {
        await repository(deck).answer(id, button: button, seconds: seconds, now: Date())
    }

    func undoAction(deck: MojiWordDeck) async -> MojiWordStudyStep? {
        await repository(deck).undo(now: Date())
    }

    func stepAction(deck: MojiWordDeck) async -> MojiWordStudyStep? {
        await repository(deck).step(now: Date())
    }

    func endSessionAction(deck: MojiWordDeck) async -> MojiWordSessionSummary? {
        await repository(deck).endSession(now: Date())
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

    func setOptionsAction(_ options: MojiWordOptions, deck: MojiWordDeck) async {
        await repository(deck).setOptions(options, now: Date())
    }

    func addTodayAction(extraNew: Int, extraReviews: Int, deck: MojiWordDeck) async {
        await repository(deck).addToday(extraNew: extraNew, extraReviews: extraReviews, now: Date())
    }

    func studyCountAction(_ scope: MojiWordScope, deck: MojiWordDeck) async -> MojiWordQueueCounts {
        await repository(deck).studyCount(for: scope, now: Date())
    }

    func markKnownAction(_ wordIDs: [String]) {
        let groups = wordIDsByDeck(wordIDs)
        Task {
            for (deck, ids) in groups {
                await repository(deck).markKnown(wordIDs: ids, now: Date())
            }
        }
    }

    func forgetAction(_ wordIDs: [String]) {
        let groups = wordIDsByDeck(wordIDs)
        Task {
            for (deck, ids) in groups {
                await repository(deck).forget(wordIDs: ids, now: Date())
            }
        }
    }

    func setSuspendedAction(_ suspended: Bool, cards: [MojiWordCardID]) {
        let groups = cardsByDeck(cards)
        Task {
            for (deck, ids) in groups {
                await repository(deck).setSuspended(suspended, cards: ids, now: Date())
            }
        }
    }

    func buryAction(_ cards: [MojiWordCardID]) {
        let groups = cardsByDeck(cards)
        Task {
            for (deck, ids) in groups {
                await repository(deck).bury(ids, now: Date())
            }
        }
    }

    func unburyAction(_ cards: [MojiWordCardID]) {
        let groups = cardsByDeck(cards)
        Task {
            for (deck, ids) in groups {
                await repository(deck).unbury(ids, now: Date())
            }
        }
    }

    func rescheduleAction(_ cards: [MojiWordCardID], inDays days: Int) {
        let groups = cardsByDeck(cards)
        Task {
            for (deck, ids) in groups {
                await repository(deck).reschedule(ids, inDays: days, now: Date())
            }
        }
    }

    func setFlagAction(_ flag: MojiWordFlag?, cards: [MojiWordCardID]) {
        let groups = cardsByDeck(cards)
        Task {
            for (deck, ids) in groups {
                await repository(deck).setFlag(flag, cards: ids, now: Date())
            }
        }
    }

    func setLeechAction(_ isLeech: Bool, cards: [MojiWordCardID]) {
        let groups = cardsByDeck(cards)
        Task {
            for (deck, ids) in groups {
                await repository(deck).setLeech(isLeech, cards: ids, now: Date())
            }
        }
    }

    func setNoteAction(_ note: String, wordID: String) {
        Task {
            await repository(MojiWordDeck.of(wordID: wordID)).setNote(note, wordID: wordID, now: Date())
        }
    }

    func historyAction(_ wordID: String) async -> [MojiWordCardID: [MojiWordReview]] {
        await repository(MojiWordDeck.of(wordID: wordID)).history(wordID: wordID)
    }

    func addOwnWordAction(_ input: MojiOwnWordInput) async -> MojiOwnWord? {
        await repository(.mine).addOwnWord(input, now: Date())
    }

    func updateOwnWordAction(_ wordID: String, input: MojiOwnWordInput) async -> MojiOwnWord? {
        await repository(.mine).updateOwnWord(wordID, with: input, now: Date())
    }

    func deleteOwnWordsAction(_ wordIDs: [String]) {
        Task {
            await repository(.mine).deleteOwnWords(wordIDs, now: Date())
        }
    }

    func resetAllAction() {
        Task {
            for deck in MojiWordDeck.allCases {
                await repository(deck).resetAll(now: Date())
            }
        }
    }

    func resetDeckAction(_ deck: MojiWordDeck) {
        Task {
            await repository(deck).resetAll(now: Date())
        }
    }

    func refreshClockAction() {
        Task {
            await domain().refreshClock()
        }
    }

    func reloadFromDiskAction() async {
        await domain().reloadFromDisk()
    }
}
