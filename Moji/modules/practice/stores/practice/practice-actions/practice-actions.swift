import Foundation
import Observation

@MainActor
@Observable
final class PracticeActionsStore {
    static let shared = PracticeActionsStore()

    private init() {}

    func startSessionAction(_ page: MojiPage) async -> MojiPracticeSession? {
        let domain = await MojiPracticeDomainRegistry.shared.requireDomain()
        return await domain.repository.startSession(
            page: page,
            now: Date()
        )
    }

    func answerAction(_ submission: MojiAnswerSubmission) async -> MojiPracticeAnswerOutcome? {
        let domain = await MojiPracticeDomainRegistry.shared.requireDomain()
        return await domain.repository.answer(submission)
    }

    func discardSessionAction(_ page: MojiPage) {
        Task {
            let domain = await MojiPracticeDomainRegistry.shared.requireDomain()
            await domain.repository.discardSession(page: page)
        }
    }

    func setStrengthAction(_ strength: Int, characterIDs: [String]) {
        Task {
            let domain = await MojiPracticeDomainRegistry.shared.requireDomain()
            await domain.repository.setStrength(
                strength,
                for: characterIDs,
                at: Date()
            )
        }
    }

    func markWrittenAction(_ characterIDs: [String]) {
        Task {
            let domain = await MojiPracticeDomainRegistry.shared.requireDomain()
            await domain.repository.markWritten(characterIDs, at: Date())
        }
    }

    func recordAnswerAction(characterID: String, correct: Bool, steps: Int = 1) {
        Task {
            let domain = await MojiPracticeDomainRegistry.shared.requireDomain()
            await domain.repository.recordAnswer(
                characterID: characterID,
                correct: correct,
                steps: steps,
                at: Date()
            )
        }
    }

    @discardableResult
    func recordLessonAction(
        page: MojiPage,
        total: Int,
        correct: Int,
        startedAt: Date
    ) async -> MojiPracticeCompletion {
        let domain = await MojiPracticeDomainRegistry.shared.requireDomain()
        return await domain.repository.recordLesson(
            page: page,
            total: total,
            correct: correct,
            startedAt: startedAt,
            at: Date()
        )
    }

    func resetProgressAction() {
        Task {
            let domain = await MojiPracticeDomainRegistry.shared.requireDomain()
            await domain.repository.resetAll()
        }
    }

    func setAnswerInputAction(_ input: MojiAnswerInput, page: MojiPage) {
        Task {
            let domain = await MojiPracticeDomainRegistry.shared.requireDomain()
            await domain.repository.setAnswerInput(input, for: page)
        }
    }

    func setAnswerSideAction(_ side: MojiAnswerSide, page: MojiPage) {
        Task {
            let domain = await MojiPracticeDomainRegistry.shared.requireDomain()
            await domain.repository.setAnswerSide(side, for: page)
        }
    }

    func copyAnswerModeAction(from page: MojiPage, to pages: [MojiPage]) {
        Task {
            let domain = await MojiPracticeDomainRegistry.shared.requireDomain()
            await domain.repository.copyAnswerMode(from: page, to: pages)
        }
    }
}
