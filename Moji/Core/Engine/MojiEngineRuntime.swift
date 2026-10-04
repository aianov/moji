import Foundation

@MainActor
final class MojiEngineRuntime {
    static let shared = MojiEngineRuntime()

    private var practiceActivation: Task<MojiPracticeDomain, Never>?
    private var learnActivation: Task<MojiLearnDomain, Never>?
    private var wordsActivation: Task<MojiWordDomain, Never>?
    private var dayChangeObserver: NSObjectProtocol?

    private init() {}

    func start() {
        _ = preparePractice()
        _ = prepareLearn()
        _ = prepareWords()
        observeDayChanges()
    }

    @discardableResult
    func preparePractice() -> Task<MojiPracticeDomain, Never> {
        if let practiceActivation {
            return practiceActivation
        }

        let task = Task { @MainActor in
            let domain = MojiPracticeDomain(
                store: .shared,
                catalog: .shared
            )
            await domain.activate()
            return domain
        }
        practiceActivation = task
        return task
    }

    @discardableResult
    func prepareLearn() -> Task<MojiLearnDomain, Never> {
        if let learnActivation {
            return learnActivation
        }

        let task = Task { @MainActor in
            let domain = MojiLearnDomain(
                store: .shared,
                planner: .shared
            )
            await domain.activate()
            return domain
        }
        learnActivation = task
        return task
    }

    @discardableResult
    func prepareWords() -> Task<MojiWordDomain, Never> {
        if let wordsActivation {
            return wordsActivation
        }

        let task = Task { @MainActor in
            let domain = MojiWordDomain(store: .shared)
            await domain.activate()
            return domain
        }
        wordsActivation = task
        return task
    }

    func clockDidMove() {
        if let practice = MojiPracticeDomainRegistry.shared.active {
            Task {
                await practice.refreshClock()
            }
        }
        if let learn = MojiLearnDomainRegistry.shared.active {
            Task {
                await learn.refreshClock()
            }
        }
        if let words = MojiWordDomainRegistry.shared.active {
            Task {
                await words.refreshClock()
            }
        }
    }

    func appDidLeaveForeground() {
        if let words = MojiWordDomainRegistry.shared.active {
            Task {
                await words.repository.flush()
            }
        }
    }

    private func observeDayChanges() {
        guard dayChangeObserver == nil else { return }

        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                MojiEngineRuntime.shared.clockDidMove()
            }
        }
    }
}
