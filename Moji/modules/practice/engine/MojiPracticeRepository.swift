import Foundation

struct MojiPracticeRepositorySnapshot: Equatable, Sendable {
    let isLoaded: Bool
    let sessions: [MojiPage: MojiPracticeSession]
    let progress: [String: MojiCharacterProgress]
    let pageStats: [MojiPage: MojiPageStats]
    let activity: MojiActivitySummary
    let totalAnswers: Int
    let totalCorrect: Int
    let answerModes: [MojiPage: MojiAnswerMode]

    static let empty = MojiPracticeRepositorySnapshot(
        isLoaded: false,
        sessions: [:],
        progress: [:],
        pageStats: [:],
        activity: .empty,
        totalAnswers: 0,
        totalCorrect: 0,
        answerModes: [:]
    )

    func answerMode(for page: MojiPage) -> MojiAnswerMode {
        answerModes[page] ?? .standard
    }
}

actor MojiPracticeRepository {
    private static let maxThinkSeconds: Double = 60

    private let resources: MojiPracticeResourceRepository
    private let catalog: MojiAlphabetCatalog
    private let composer: MojiQuizComposer

    private var sessions: [MojiPage: MojiPracticeSession] = [:]
    private var progress: [String: MojiCharacterProgress] = [:]
    private var activity = MojiActivityLog.empty
    private var summary = MojiActivitySummary.empty
    private var pageStats: [MojiPage: MojiPageStats] = [:]
    private var totalAnswers = 0
    private var totalCorrect = 0
    private var answerModes: [MojiPage: MojiAnswerMode] = [:]

    private var isLoaded = false
    private var loadTask: Task<Void, Never>?
    private var publish: (@Sendable (MojiPracticeRepositorySnapshot) async -> Void)?

    init(
        resources: MojiPracticeResourceRepository,
        catalog: MojiAlphabetCatalog,
        strokes: MojiStrokeLibrary? = MojiStrokeLibrary.shared
    ) {
        self.resources = resources
        self.catalog = catalog
        self.composer = MojiQuizComposer(catalog: catalog, strokes: strokes)
    }

    func setPublisher(_ publish: @escaping @Sendable (MojiPracticeRepositorySnapshot) async -> Void) {
        self.publish = publish
    }

    func activate() async -> MojiPracticeRepositorySnapshot {
        await ensureLoaded()
        return snapshot()
    }

    func startSession(
        page: MojiPage,
        now: Date
    ) async -> MojiPracticeSession? {
        await ensureLoaded()

        if let existing = sessions[page], !existing.isComplete, existing.current != nil {
            return existing
        }

        var generator = SystemRandomNumberGenerator()
        let order = composer.makeOrder(page: page, using: &generator)
        guard let first = order.first,
              let question = composer.makeQuestion(
                for: first,
                mode: answerMode(for: page),
                using: &generator
              ) else {
            return nil
        }

        let session = MojiPracticeSession(
            id: UUID(),
            page: page,
            order: order,
            answers: [],
            current: question,
            combo: 0,
            bestCombo: 0,
            startedAt: now,
            updatedAt: now,
            activeSeconds: 0
        )
        sessions[page] = session

        await resources.saveSessions(Array(sessions.values))
        await emit()
        return session
    }

    func answer(_ submission: MojiAnswerSubmission) async -> MojiPracticeAnswerOutcome? {
        await ensureLoaded()

        guard var session = sessions[submission.page],
              session.id == submission.sessionID,
              session.answeredCount == submission.questionIndex,
              let question = session.current else {
            return nil
        }

        let isDrawing = question.input == .drawing
        let isCorrect = MojiAnswerChecker.isCorrect(
            chosenID: submission.chosenID,
            typed: submission.typed,
            drawn: submission.drawn,
            question: question,
            answer: catalog.character(question.characterID)
        )
        session.answers.append(
            MojiQuizAnswer(
                characterID: question.characterID,
                chosenID: submission.typed == nil && !isDrawing ? submission.chosenID : nil,
                typed: isDrawing ? nil : submission.typed,
                drawn: isDrawing ? submission.drawn : nil,
                isCorrect: isCorrect,
                answeredAt: submission.answeredAt
            )
        )
        session.combo = isCorrect ? session.combo + 1 : 0
        session.bestCombo = max(session.bestCombo, session.combo)
        session.activeSeconds += min(max(0, submission.thinkSeconds), Self.maxThinkSeconds)
        session.updatedAt = submission.answeredAt
        progress[question.characterID] = (progress[question.characterID] ?? .fresh)
            .recording(correct: isCorrect, at: submission.answeredAt)

        if session.isComplete {
            let completion = complete(session, at: submission.answeredAt)
            await resources.saveActivity(activity)
            await resources.saveProgress(progress)
            await resources.saveSessions(Array(sessions.values))
            await emit()
            return .completed(completion)
        }

        var generator = SystemRandomNumberGenerator()
        session.current = nextQuestion(in: session, using: &generator)
        sessions[submission.page] = session
        recomputeDerived(now: submission.answeredAt)

        await resources.saveSessions(Array(sessions.values))
        await resources.saveProgress(progress)
        await emit()
        return .next(session)
    }

    func setAnswerMode(_ mode: MojiAnswerMode, for pages: [MojiPage]) async {
        await updateAnswerModes(for: pages) { $0 = mode }
    }

    func setAnswerInput(_ input: MojiAnswerInput, for page: MojiPage) async {
        await updateAnswerModes(for: [page]) { $0.input = input }
    }

    func setAnswerSide(_ side: MojiAnswerSide, for page: MojiPage) async {
        await updateAnswerModes(for: [page]) { $0.side = side }
    }

    func copyAnswerMode(from source: MojiPage, to pages: [MojiPage]) async {
        await ensureLoaded()
        let mode = answerMode(for: source)
        await updateAnswerModes(for: pages) { $0 = mode }
    }

    private func updateAnswerModes(
        for pages: [MojiPage],
        _ change: (inout MojiAnswerMode) -> Void
    ) async {
        await ensureLoaded()
        var changed = false
        for page in pages {
            var mode = answerMode(for: page)
            change(&mode)
            guard mode != answerMode(for: page) else { continue }
            answerModes[page] = mode
            changed = true
        }
        guard changed else { return }

        await resources.saveAnswerModes(answerModes)
        await emit()
    }

    func discardSession(page: MojiPage) async {
        await ensureLoaded()
        guard sessions.removeValue(forKey: page) != nil else { return }

        await resources.saveSessions(Array(sessions.values))
        await emit()
    }

    func setStrength(
        _ strength: Int,
        for characterIDs: [String],
        at date: Date
    ) async {
        await ensureLoaded()
        let level = min(MojiCharacterProgress.masteryLevel, max(0, strength))
        var changed = false
        for id in characterIDs where catalog.character(id) != nil {
            var entry = progress[id] ?? .fresh
            guard entry.strength != level else { continue }
            entry.strength = level
            if entry.lastSeenAt == nil {
                entry.lastSeenAt = date
            }
            progress[id] = entry
            changed = true
        }
        guard changed else { return }
        recomputeDerived(now: date)

        await resources.saveProgress(progress)
        await emit()
    }

    func markWritten(_ characterIDs: [String], at date: Date) async {
        await ensureLoaded()
        var changed = false
        for id in characterIDs where catalog.character(id) != nil {
            let entry = progress[id] ?? .fresh
            guard !entry.isWritten else { continue }
            progress[id] = entry.writing(at: date)
            changed = true
        }
        guard changed else { return }
        recomputeDerived(now: date)

        await resources.saveProgress(progress)
        await emit()
    }

    func recordAnswer(
        characterID: String,
        correct: Bool,
        steps: Int = 1,
        at date: Date
    ) async {
        await ensureLoaded()
        guard catalog.character(characterID) != nil else { return }
        progress[characterID] = (progress[characterID] ?? .fresh)
            .recording(correct: correct, at: date, steps: steps)
        recomputeDerived(now: date)

        await resources.saveProgress(progress)
        await emit()
    }

    func recordLesson(
        page: MojiPage,
        total: Int,
        correct: Int,
        startedAt: Date,
        at now: Date
    ) async -> MojiPracticeCompletion {
        await ensureLoaded()
        let dayKey = MojiDayKey.make(now, calendar: Calendar.current)
        let wasDoneToday = activity.completed.contains { $0.dayKey == dayKey }

        let record = MojiCompletedSession(
            id: UUID(),
            page: page,
            script: page.script,
            dayKey: dayKey,
            startedAt: startedAt,
            completedAt: now,
            total: total,
            correct: correct,
            bestCombo: 0,
            activeSeconds: max(0, now.timeIntervalSince(startedAt)),
            mistakeIDs: [],
            kind: .lesson
        )
        appendToLog(record)
        recomputeDerived(now: now)

        await resources.saveActivity(activity)
        await emit()
        return MojiPracticeCompletion(
            record: record,
            page: page,
            streak: summary.currentStreak,
            extendedStreak: !wasDoneToday
        )
    }

    func resetAll() async {
        await ensureLoaded()
        sessions = [:]
        progress = [:]
        activity = .empty
        recomputeDerived(now: Date())

        await resources.clear()
        await emit()
    }

    func refreshClock() async {
        await ensureLoaded()
        let before = summary
        recomputeDerived(now: Date())
        guard summary != before else { return }
        await emit()
    }

    private func appendToLog(_ record: MojiCompletedSession) {
        activity.completed.append(record)
        if activity.completed.count > MojiActivityLog.maxEntries {
            activity.completed.removeFirst(activity.completed.count - MojiActivityLog.maxEntries)
        }
    }

    private func complete(
        _ session: MojiPracticeSession,
        at now: Date
    ) -> MojiPracticeCompletion {
        let dayKey = MojiDayKey.make(now, calendar: Calendar.current)
        let wasDoneToday = activity.completed.contains { $0.dayKey == dayKey }

        let record = MojiCompletedSession(
            id: session.id,
            page: session.page,
            script: session.script,
            dayKey: dayKey,
            startedAt: session.startedAt,
            completedAt: now,
            total: session.total,
            correct: session.correctCount,
            bestCombo: session.bestCombo,
            activeSeconds: session.activeSeconds,
            mistakeIDs: session.answers.filter { !$0.isCorrect }.map(\.characterID)
        )
        appendToLog(record)
        sessions[session.page] = nil
        recomputeDerived(now: now)

        return MojiPracticeCompletion(
            record: record,
            page: session.page,
            streak: summary.currentStreak,
            extendedStreak: !wasDoneToday
        )
    }

    private func nextQuestion<R: RandomNumberGenerator>(
        in session: MojiPracticeSession,
        using generator: inout R
    ) -> MojiQuizQuestion? {
        guard session.answeredCount < session.order.count else { return nil }
        return composer.makeQuestion(
            for: session.order[session.answeredCount],
            mode: answerMode(for: session.page),
            using: &generator
        )
    }

    private func answerMode(for page: MojiPage) -> MojiAnswerMode {
        answerModes[page] ?? .standard
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
        let cache = await resources.load()
        answerModes = cache.answerModes.filter { catalog.pages.contains($0.key) }

        var restored: [MojiPage: MojiPracticeSession] = [:]
        for session in cache.sessions where catalog.pages.contains(session.page) {
            guard let sanitized = sanitize(session) else { continue }
            restored[sanitized.page] = sanitized
        }
        sessions = restored
        progress = cache.progress.filter { catalog.character($0.key) != nil }
        activity = cache.activity
        isLoaded = true
        recomputeDerived(now: Date())
    }

    private func sanitize(_ stored: MojiPracticeSession) -> MojiPracticeSession? {
        let answered = Set(stored.answers.map(\.characterID))
        let known = stored.order.filter { catalog.character($0) != nil }
        let answers = stored.answers.filter { catalog.character($0.characterID) != nil }
        let remaining = known.filter { !answered.contains($0) }
        guard !remaining.isEmpty else { return nil }

        let order = answers.map(\.characterID) + remaining
        var session = MojiPracticeSession(
            id: stored.id,
            page: stored.page,
            order: order,
            answers: answers,
            current: stored.current,
            combo: stored.combo,
            bestCombo: stored.bestCombo,
            startedAt: stored.startedAt,
            updatedAt: stored.updatedAt,
            activeSeconds: stored.activeSeconds
        )

        let expectedID = order[answers.count]
        let currentIsValid = session.current.map { question in
            question.characterID == expectedID && composer.isPlayable(question)
        } ?? false
        if !currentIsValid {
            var generator = SystemRandomNumberGenerator()
            session.current = composer.makeQuestion(
                for: expectedID,
                mode: answerMode(for: stored.page),
                using: &generator
            )
        }
        return session.current == nil ? nil : session
    }

    private func recomputeDerived(now: Date) {
        summary = MojiStreakCalculator.summary(
            log: activity,
            now: now,
            calendar: Calendar.current
        )

        var stats: [MojiPage: MojiPageStats] = [:]
        for page in catalog.pages {
            let pool = catalog.pool(page)
            var practiced = 0
            var mastered = 0
            for character in pool {
                guard let entry = progress[character.id], entry.seen > 0 else { continue }
                practiced += 1
                if entry.isMastered {
                    mastered += 1
                }
            }
            stats[page] = MojiPageStats(
                total: pool.count,
                practiced: practiced,
                mastered: mastered
            )
        }
        pageStats = stats

        totalAnswers = progress.values.reduce(0) { $0 + $1.seen }
        totalCorrect = progress.values.reduce(0) { $0 + $1.correct }
    }

    private func snapshot() -> MojiPracticeRepositorySnapshot {
        MojiPracticeRepositorySnapshot(
            isLoaded: isLoaded,
            sessions: sessions,
            progress: progress,
            pageStats: pageStats,
            activity: summary,
            totalAnswers: totalAnswers,
            totalCorrect: totalCorrect,
            answerModes: answerModes
        )
    }

    private func emit() async {
        guard let publish else { return }
        await publish(snapshot())
    }
}

extension MojiPracticeRepository {
    func recordWordsSession(
        total: Int,
        correct: Int,
        startedAt: Date,
        activeSeconds: Double,
        at now: Date
    ) async -> (record: MojiCompletedSession, streak: Int, extendedStreak: Bool) {
        await ensureLoaded()
        let dayKey = MojiDayKey.make(now, calendar: Calendar.current)
        let wasDoneToday = activity.completed.contains { $0.dayKey == dayKey }

        let record = MojiCompletedSession(
            id: UUID(),
            page: nil,
            script: .kanji,
            dayKey: dayKey,
            startedAt: startedAt,
            completedAt: now,
            total: max(0, total),
            correct: min(max(0, correct), max(0, total)),
            bestCombo: 0,
            activeSeconds: max(0, activeSeconds),
            mistakeIDs: [],
            kind: .words
        )
        appendToLog(record)
        recomputeDerived(now: now)

        await resources.saveActivity(activity)
        await emit()
        return (record, summary.currentStreak, !wasDoneToday)
    }
}
