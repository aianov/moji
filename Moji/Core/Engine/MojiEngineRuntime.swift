import Foundation

@MainActor
final class MojiEngineRuntime {
    static let shared = MojiEngineRuntime()

    private var practiceActivation: Task<MojiPracticeDomain, Never>?
    private var learnActivation: Task<MojiLearnDomain, Never>?
    private var wordsActivation: Task<MojiWordDomain, Never>?
    private var notesActivation: Task<MojiNoteDomain, Never>?
    private var dayChangeObserver: NSObjectProtocol?
    private var reloads: [MojiEngineReload] = []
    private var isReplacingData = false

    private init() {}

    func start() {
        _ = preparePractice()
        _ = prepareLearn()
        _ = prepareWords()
        _ = prepareNotes()
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
        registerReload("practice") { await task.value.reloadFromDisk() }
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
        registerReload("learn") { await task.value.reloadFromDisk() }
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
        registerReload(
            "words",
            flush: { await task.value.flush() },
            reload: { await task.value.reloadFromDisk() }
        )
        return task
    }

    @discardableResult
    func prepareNotes() -> Task<MojiNoteDomain, Never> {
        if let notesActivation {
            return notesActivation
        }

        let task = Task { @MainActor in
            let domain = MojiNoteDomain(store: .shared)
            await domain.activate()
            return domain
        }
        notesActivation = task
        registerReload("notes") { await task.value.reloadFromDisk() }
        return task
    }

    func registerReload(
        _ name: String,
        flush: (@Sendable () async -> Void)? = nil,
        reload: @escaping @Sendable () async -> Void
    ) {
        reloads.removeAll { $0.name == name }
        reloads.append(MojiEngineReload(name: name, flush: flush, reload: reload))
    }

    func flushAll() async {
        for flush in reloads.compactMap(\.flush) {
            await flush()
        }
    }

    func reloadAll() async {
        await MojiDiskStore.shared.clearMemory()
        let pending = reloads.map(\.reload)
        await withTaskGroup(of: Void.self) { group in
            for reload in pending {
                group.addTask {
                    await reload()
                }
            }
        }
    }

    func replaceData<Value: Sendable>(
        _ replace: @Sendable () async throws -> Value
    ) async throws -> Value {
        isReplacingData = true
        defer { isReplacingData = false }
        await flushAll()
        let result = try await replace()
        await reloadAll()
        return result
    }

    func clockDidMove() {
        guard !isReplacingData else { return }
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
        guard !isReplacingData else { return }
        if let words = MojiWordDomainRegistry.shared.active {
            Task {
                await words.repository.flush()
                await words.mine.flush()
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

private struct MojiEngineReload {
    let name: String
    let flush: (@Sendable () async -> Void)?
    let reload: @Sendable () async -> Void
}
