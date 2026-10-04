import Foundation
import Observation

@MainActor
@Observable
final class LearnActionsStore {
    static let shared = LearnActionsStore()

    private init() {}

    func makeLessonAction(
        _ page: MojiPage,
        batchIndex: Int?,
        progress: [String: MojiCharacterProgress]
    ) async -> MojiLesson? {
        let domain = await MojiLearnDomainRegistry.shared.requireDomain()
        return await domain.repository.makeLesson(
            page: page,
            batchIndex: batchIndex,
            progress: progress,
            now: Date()
        )
    }

    func completeLessonAction(_ lesson: MojiLesson) {
        Task {
            let domain = await MojiLearnDomainRegistry.shared.requireDomain()
            await domain.repository.completeLesson(lesson, at: Date())
        }
    }

    func markWrittenAction(_ batchID: String, on page: MojiPage) {
        Task {
            let domain = await MojiLearnDomainRegistry.shared.requireDomain()
            await domain.repository.markWritten(batchID, on: page)
        }
    }

    func retryItem(_ item: MojiLessonItem) -> MojiLessonItem {
        var generator = SystemRandomNumberGenerator()
        return MojiLearnPlanner.shared.retry(of: item, using: &generator)
    }

    func recordAnswerAction(characterID: String, correct: Bool, steps: Int) {
        PracticeActionsStore.shared.recordAnswerAction(
            characterID: characterID,
            correct: correct,
            steps: steps
        )
    }

    func recordLessonActivityAction(
        page: MojiPage,
        total: Int,
        correct: Int,
        startedAt: Date
    ) {
        Task {
            await PracticeActionsStore.shared.recordLessonAction(
                page: page,
                total: total,
                correct: correct,
                startedAt: startedAt
            )
        }
    }

    func setStrengthAction(_ strength: Int, characterIDs: [String]) {
        PracticeActionsStore.shared.setStrengthAction(
            strength,
            characterIDs: characterIDs
        )
    }

    func resetAllAction() {
        Task {
            let domain = await MojiLearnDomainRegistry.shared.requireDomain()
            await domain.repository.resetAll()
        }
    }
}
