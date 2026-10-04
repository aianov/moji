import Foundation

struct MojiLearnRepositorySnapshot: Equatable, Sendable {
    let isLoaded: Bool
    let state: MojiLearnState
    let clock: Date

    static let empty = MojiLearnRepositorySnapshot(
        isLoaded: false,
        state: .empty,
        clock: Date()
    )
}

actor MojiLearnRepository {
    private let resources: MojiLearnResourceRepository
    private let planner: MojiLearnPlanner

    private var state = MojiLearnState.empty
    private var clock = Date()
    private var isLoaded = false
    private var loadTask: Task<Void, Never>?
    private var publish: (@Sendable (MojiLearnRepositorySnapshot) async -> Void)?

    init(
        resources: MojiLearnResourceRepository,
        planner: MojiLearnPlanner
    ) {
        self.resources = resources
        self.planner = planner
    }

    func setPublisher(_ publish: @escaping @Sendable (MojiLearnRepositorySnapshot) async -> Void) {
        self.publish = publish
    }

    func activate() async -> MojiLearnRepositorySnapshot {
        await ensureLoaded()
        return snapshot()
    }

    func makeLesson(
        page: MojiPage,
        batchIndex: Int?,
        progress: [String: MojiCharacterProgress],
        now: Date
    ) async -> MojiLesson? {
        await ensureLoaded()
        var generator = SystemRandomNumberGenerator()
        return planner.makeLesson(
            page: page,
            progress: progress,
            state: state.state(for: page),
            now: now,
            batchIndex: batchIndex,
            using: &generator
        )
    }

    func completeLesson(_ lesson: MojiLesson, at date: Date) async {
        await ensureLoaded()
        state.pages[lesson.page.rawValue] = state.state(for: lesson.page).completing(lesson, at: date)
        clock = date

        await resources.save(state)
        await emit()
    }

    func resetAll() async {
        await ensureLoaded()
        state = .empty

        await resources.clear()
        await emit()
    }

    func refreshClock() async {
        await ensureLoaded()
        clock = Date()
        await emit()
    }

    static func restore(_ stored: MojiLearnState, catalog: MojiAlphabetCatalog) -> MojiLearnState {
        var pages: [String: MojiLearnPageState] = [:]
        for (key, value) in stored.pages {
            guard let page = MojiPage(rawValue: key), catalog.pages.contains(page) else { continue }
            let members = Set(catalog.pool(page).map(\.id))
            var sanitized = value
            sanitized.introducedIDs = value.introducedIDs.filter(members.contains)
            sanitized.freshIDs = value.freshIDs.filter(members.contains)
            pages[key] = sanitized
        }

        let legacy = MojiPage.legacyKanjiKeys.compactMap { stored.pages[$0] }
        guard !legacy.isEmpty else { return MojiLearnState(pages: pages) }

        var seen: Set<String> = []
        let introduced = legacy.flatMap(\.introducedIDs).filter { seen.insert($0).inserted }
        let fresh = Set(legacy.flatMap(\.freshIDs))
        let lastLessonAt = legacy.compactMap(\.lastLessonAt).max()
        for page in catalog.pages(.kanji) where pages[page.rawValue] == nil {
            let members = Set(catalog.pool(page).map(\.id))
            let ids = introduced.filter(members.contains)
            guard !ids.isEmpty else { continue }
            pages[page.rawValue] = MojiLearnPageState(
                introducedIDs: ids,
                freshIDs: ids.filter(fresh.contains),
                lessonsCompleted: 0,
                lastLessonAt: lastLessonAt
            )
        }
        return MojiLearnState(pages: pages)
    }

    private func ensureLoaded() async {
        if isLoaded { return }
        if let loadTask {
            await loadTask.value
            return
        }

        let task = Task {
            await self.load()
        }
        loadTask = task
        await task.value
    }

    private func load() async {
        let stored = await resources.load()
        state = Self.restore(stored, catalog: planner.catalog)
        clock = Date()
        isLoaded = true
    }

    private func snapshot() -> MojiLearnRepositorySnapshot {
        MojiLearnRepositorySnapshot(
            isLoaded: isLoaded,
            state: state,
            clock: clock
        )
    }

    private func emit() async {
        guard let publish else { return }
        await publish(snapshot())
    }
}
