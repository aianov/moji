import Foundation

struct MojiPracticeCache: Sendable {
    let sessions: [MojiPracticeSession]
    let progress: [String: MojiCharacterProgress]
    let activity: MojiActivityLog
    let answerModes: [MojiPage: MojiAnswerMode]
}

struct MojiPracticeResourceRepository: Sendable {
    private static let version = 1
    private static let sessionsKey = MojiDiskKey(namespace: "practice", name: "sessions")
    private static let progressKey = MojiDiskKey(namespace: "practice", name: "progress")
    private static let activityKey = MojiDiskKey(namespace: "practice", name: "activity")

    private static let answerModesVersion = 1
    private static let answerModesKey = MojiDiskKey(namespace: "practice", name: "answer_modes")

    let store: MojiDiskStore

    func load() async -> MojiPracticeCache {
        let sessions = await store.read(
            MojiLossyArray<MojiPracticeSession>.self,
            key: Self.sessionsKey,
            version: Self.version
        )
        let progress = await store.read(
            [String: MojiCharacterProgress].self,
            key: Self.progressKey,
            version: Self.version
        )
        let activity = await store.read(
            MojiActivityLog.self,
            key: Self.activityKey,
            version: Self.version
        )
        let storedModes = await store.read(
            [String: MojiAnswerMode].self,
            key: Self.answerModesKey,
            version: Self.answerModesVersion
        ) ?? [:]

        return MojiPracticeCache(
            sessions: sessions?.elements ?? [],
            progress: progress ?? [:],
            activity: activity ?? .empty,
            answerModes: Self.answerModes(from: storedModes)
        )
    }

    static func answerModes(from stored: [String: MojiAnswerMode]) -> [MojiPage: MojiAnswerMode] {
        var modes: [MojiPage: MojiAnswerMode] = [:]
        for (rawPage, mode) in stored {
            guard let page = MojiPage(rawValue: rawPage) else { continue }
            modes[page] = mode
        }
        guard let legacy = MojiPage.legacyKanjiKeys.lazy.compactMap({ stored[$0] }).first else {
            return modes
        }
        for theme in MojiKanjiTheme.allCases where modes[.kanji(theme)] == nil {
            modes[.kanji(theme)] = legacy
        }
        return modes
    }

    func saveSessions(_ sessions: [MojiPracticeSession]) async {
        await store.write(
            sessions,
            key: Self.sessionsKey,
            version: Self.version
        )
    }

    func saveProgress(_ progress: [String: MojiCharacterProgress]) async {
        await store.write(
            progress,
            key: Self.progressKey,
            version: Self.version
        )
    }

    func saveActivity(_ activity: MojiActivityLog) async {
        await store.write(
            activity,
            key: Self.activityKey,
            version: Self.version
        )
    }

    func saveAnswerModes(_ modes: [MojiPage: MojiAnswerMode]) async {
        var stored: [String: MojiAnswerMode] = [:]
        for (page, mode) in modes {
            stored[page.rawValue] = mode
        }
        await store.write(
            stored,
            key: Self.answerModesKey,
            version: Self.answerModesVersion
        )
    }

    func clear() async {
        await store.remove(Self.sessionsKey)
        await store.remove(Self.progressKey)
        await store.remove(Self.activityKey)
    }
}
