import Foundation
import Testing
@testable import Moji

@Suite("Data saved before kanji themes")
struct MojiLegacyDataTests {
    private let catalog = MojiAlphabetCatalog.shared

    private func scratchDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("moji-legacy-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func write(_ value: String, to name: String, in directory: URL) throws {
        let envelope = #"{"savedAt":0,"value":"# + value + #","version":1}"#
        try Data(envelope.utf8).write(to: directory.appendingPathComponent(name))
    }

    private func practice(at directory: URL) -> MojiPracticeRepository {
        MojiPracticeRepository(
            resources: MojiPracticeResourceRepository(store: MojiDiskStore(directory: directory)),
            catalog: catalog
        )
    }

    private func learn(at directory: URL) -> MojiLearnRepository {
        MojiLearnRepository(
            resources: MojiLearnResourceRepository(store: MojiDiskStore(directory: directory)),
            planner: .shared
        )
    }

    private func session(_ script: String, order: [String], current: String) -> String {
        let options = order.map { "\"\($0)\"" }.joined(separator: ",")
        return #"{"activeSeconds":3,"answers":[],"bestCombo":0,"combo":0,"current":{"characterID":""#
            + current + #"","direction":"glyph_to_romaji","optionIDs":["# + options
            + #"]},"id":""# + UUID().uuidString + #"","order":["# + options
            + #"],"script":""# + script + #"","startedAt":0,"updatedAt":0}"#
    }

    private func record(_ script: String, dayKey: String, kind: String? = nil) -> String {
        let kindField = kind.map { #","kind":""# + $0 + "\"" } ?? ""
        return #"{"activeSeconds":60,"bestCombo":4,"completedAt":60,"correct":10,"dayKey":""# + dayKey
            + #"","id":""# + UUID().uuidString + #"","mistakeIDs":[],"script":""# + script
            + #"","startedAt":0,"total":12"# + kindField + "}"
    }

    @Test("Mastery from Kanji and Kanji+ stays with each kanji in its new theme")
    func masteryIsKept() async throws {
        let directory = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try write(
            #"""
            {"j-人":{"strength":5,"seen":9,"correct":9,"lastSeenAt":100},
             "j-日":{"strength":3,"seen":4,"correct":3,"lastSeenAt":100},
             "j-國":{"strength":5,"seen":6,"correct":6,"lastSeenAt":100},
             "j-亀":{"strength":2,"seen":3,"correct":2,"lastSeenAt":100},
             "j-𠀋":{"strength":5,"seen":5,"correct":5,"lastSeenAt":100}}
            """#,
            to: "practice.progress.json",
            in: directory
        )

        let snapshot = await practice(at: directory).activate()
        #expect(snapshot.progress["j-人"]?.strength == 5)
        #expect(snapshot.progress["j-日"]?.strength == 3)
        #expect(snapshot.progress["j-國"]?.strength == 5)
        #expect(snapshot.progress["j-亀"]?.seen == 3)
        #expect(snapshot.progress["j-𠀋"] == nil)

        #expect(snapshot.pageStats[.kanji(.people)]?.practiced == 1)
        #expect(snapshot.pageStats[.kanji(.people)]?.mastered == 0)
        #expect(snapshot.progress["j-人"]?.isRecognized == true)
        #expect(snapshot.progress["j-人"]?.isWritten == false)
        #expect(snapshot.pageStats[.kanji(.time)]?.practiced == 1)
        #expect(snapshot.pageStats[.kanji(.time)]?.mastered == 0)
        #expect(snapshot.pageStats[.kanji(.oldForms)]?.practiced == 1)
        #expect(snapshot.progress["j-國"]?.isRecognized == true)
        #expect(snapshot.pageStats[.kanji(.animals)]?.practiced == 1)
        #expect(snapshot.pageStats[.kanji(.names)]?.practiced == 0)
        #expect(snapshot.totalAnswers == 22)
    }

    @Test("Started Kanji and Kanji+ sessions are dropped, kana sessions resume")
    func oldKanjiSessionsAreDropped() async throws {
        let directory = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sessions = [
            session("hiragana", order: ["h-a", "h-i", "h-u", "h-e"], current: "h-a"),
            session("kanji", order: ["j-人", "j-日", "j-見", "j-新"], current: "j-人"),
            session("kanji_plus", order: ["j-國", "j-亀", "j-猫", "j-冬"], current: "j-國"),
            #"{"id":"not a session"}"#,
            "42"
        ]
        try write("[" + sessions.joined(separator: ",") + "]", to: "practice.sessions.json", in: directory)

        let repository = practice(at: directory)
        let snapshot = await repository.activate()
        #expect(Array(snapshot.sessions.keys) == [.hiragana])
        #expect(snapshot.sessions[.hiragana]?.total == 4)

        let fresh = try #require(await repository.startSession(page: .kanji(.people), now: Date()))
        #expect(fresh.answeredCount == 0)
        #expect(Set(fresh.order) == Set(catalog.pool(.kanji(.people)).map(\.id)))
        let reloaded = await practice(at: directory).activate()
        #expect(Set(reloaded.sessions.keys) == [.hiragana, .kanji(.people)])
    }

    @Test("The activity log keeps Kanji and Kanji+ days, so the streak survives")
    func activityIsKept() async throws {
        let directory = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let calendar = Calendar.current
        let today = MojiDayKey.make(Date(), calendar: calendar)
        let yesterday = MojiDayKey.make(try #require(calendar.date(byAdding: .day, value: -1, to: Date())), calendar: calendar)
        let records = [
            record("kanji", dayKey: yesterday),
            record("kanji_plus", dayKey: today, kind: "lesson"),
            record("hiragana", dayKey: today),
            record("klingon", dayKey: today),
            record("kanji", dayKey: today, kind: "telepathy")
        ]
        try write(#"{"completed":["# + records.joined(separator: ",") + "]}", to: "practice.activity.json", in: directory)

        let repository = practice(at: directory)
        let snapshot = await repository.activate()
        #expect(snapshot.activity.totalSessions == 4)
        #expect(snapshot.activity.isTodayDone)
        #expect(snapshot.activity.currentStreak == 2)
        #expect(snapshot.activity.pagesDoneToday == [.hiragana])

        let completion = await repository.recordLesson(
            page: .kanji(.time),
            total: 12,
            correct: 12,
            startedAt: Date().addingTimeInterval(-60),
            at: Date()
        )
        #expect(!completion.extendedStreak)
        #expect(completion.streak == 2)
        let reloaded = await practice(at: directory).activate()
        #expect(reloaded.activity.totalSessions == 5)
        #expect(reloaded.activity.pagesDoneToday == [.hiragana, .kanji(.time)])
    }

    @Test("Old records read back with their script and no page")
    func oldRecordsDecode() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let plus = try decoder.decode(MojiCompletedSession.self, from: Data(record("kanji_plus", dayKey: "2026-10-01").utf8))
        #expect(plus.script == .kanji)
        #expect(plus.page == nil)
        let kanji = try decoder.decode(MojiCompletedSession.self, from: Data(record("kanji", dayKey: "2026-10-01").utf8))
        #expect(kanji.script == .kanji)
        #expect(kanji.page == nil)
        let kana = try decoder.decode(MojiCompletedSession.self, from: Data(record("katakana", dayKey: "2026-10-01").utf8))
        #expect(kana.page == .katakana)
        #expect(throws: DecodingError.self) {
            try decoder.decode(MojiCompletedSession.self, from: Data(record("klingon", dayKey: "2026-10-01").utf8))
        }
    }

    @Test("The old Kanji answer mode carries over to every theme")
    func answerModeCarriesOver() async throws {
        let directory = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try write(
            #"""
            {"kanji":{"input":"keyboard","side":"character"},
             "kanji_plus":{"input":"mixed","side":"mixed"},
             "hiragana":{"input":"keyboard","side":"romaji"}}
            """#,
            to: "practice.answer_modes.json",
            in: directory
        )

        let repository = practice(at: directory)
        let snapshot = await repository.activate()
        for theme in MojiKanjiTheme.allCases {
            #expect(snapshot.answerMode(for: .kanji(theme)) == MojiAnswerMode(input: .keyboard, side: .character), "\(theme.rawValue)")
        }
        #expect(snapshot.answerMode(for: .hiragana) == MojiAnswerMode(input: .keyboard, side: .romaji))
        #expect(snapshot.answerMode(for: .katakana) == .standard)

        await repository.setAnswerSide(.romaji, for: .kanji(.people))
        let reloaded = await practice(at: directory).activate()
        #expect(reloaded.answerMode(for: .kanji(.people)) == MojiAnswerMode(input: .keyboard, side: .romaji))
        #expect(reloaded.answerMode(for: .kanji(.time)) == MojiAnswerMode(input: .keyboard, side: .character))
    }

    @Test("Kanji+ alone carries its mode; a theme's own mode wins")
    func answerModeMapping() {
        let plusOnly = MojiPracticeResourceRepository.answerModes(from: [
            "kanji_plus": MojiAnswerMode(input: .mixed, side: .romaji)
        ])
        #expect(plusOnly.count == MojiKanjiTheme.allCases.count)
        #expect(plusOnly[.kanji(.oldForms)] == MojiAnswerMode(input: .mixed, side: .romaji))

        let mixed = MojiPracticeResourceRepository.answerModes(from: [
            "kanji": MojiAnswerMode(input: .keyboard, side: .character),
            "kanji.people": MojiAnswerMode(input: .list, side: .romaji),
            "kanji.nope": MojiAnswerMode(input: .mixed, side: .mixed),
            "katakana": MojiAnswerMode(input: .list, side: .character)
        ])
        #expect(mixed[.kanji(.people)] == MojiAnswerMode(input: .list, side: .romaji))
        #expect(mixed[.kanji(.names)] == MojiAnswerMode(input: .keyboard, side: .character))
        #expect(mixed[.katakana] == MojiAnswerMode(input: .list, side: .character))
        #expect(mixed[.hiragana] == nil)
        #expect(mixed.count == MojiKanjiTheme.allCases.count + 1)

        #expect(MojiPracticeResourceRepository.answerModes(from: [:]).isEmpty)
    }

    @Test("Kanji and Kanji+ lesson paths move into the themes their kanji belong to")
    func learnStateMoves() async throws {
        let directory = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try write(
            #"""
            {"scripts":{
             "kanji":{"introducedIDs":["j-人","j-日","j-生","j-gone"],"freshIDs":["j-生"],"lessonsCompleted":4,"lastLessonAt":100},
             "kanji_plus":{"introducedIDs":["j-國","j-亀","j-人"],"freshIDs":["j-亀"],"lessonsCompleted":2,"lastLessonAt":200},
             "hiragana":{"introducedIDs":["h-a","h-i"],"freshIDs":["h-i"],"lessonsCompleted":1,"lastLessonAt":50}}}
            """#,
            to: "learn.state.json",
            in: directory
        )

        let state = await learn(at: directory).activate().state
        #expect(state.pages["kanji"] == nil)
        #expect(state.pages["kanji_plus"] == nil)
        #expect(state.state(for: .hiragana) == MojiLearnPageState(
            introducedIDs: ["h-a", "h-i"],
            freshIDs: ["h-i"],
            lessonsCompleted: 1,
            lastLessonAt: Date(timeIntervalSince1970: 50)
        ))

        let latest = Date(timeIntervalSince1970: 200)
        #expect(state.state(for: .kanji(.people)) == MojiLearnPageState(
            introducedIDs: ["j-人", "j-生"],
            freshIDs: ["j-生"],
            lessonsCompleted: 0,
            lastLessonAt: latest
        ))
        #expect(state.state(for: .kanji(.time)).introducedIDs == ["j-日"])
        #expect(state.state(for: .kanji(.oldForms)).introducedIDs == ["j-國"])
        #expect(state.state(for: .kanji(.animals)).freshIDs == ["j-亀"])
        #expect(state.state(for: .kanji(.names)) == .empty)
        #expect(Set(state.pages.keys) == ["hiragana", "kanji.people", "kanji.time", "kanji.old_forms", "kanji.animals"])

        let progress = ["j-人": MojiCharacterProgress(strength: 5, seen: 5, correct: 5, lastSeenAt: latest)]
        let path = MojiLearnPlanner.shared.path(page: .kanji(.people), progress: progress, state: state.state(for: .kanji(.people)))
        #expect(!path.batches.isEmpty)
        #expect(MojiLearnPlanner.shared.metIDs(page: .kanji(.people), progress: progress, state: state.state(for: .kanji(.people))).contains("j-人"))
    }

    @Test("A theme already saved is not overwritten by the old pages")
    func savedThemeWins() {
        let saved = MojiLearnPageState(
            introducedIDs: ["j-自"],
            freshIDs: [],
            lessonsCompleted: 3,
            lastLessonAt: Date(timeIntervalSince1970: 300)
        )
        let stored = MojiLearnState(pages: [
            "kanji.people": saved,
            "kanji": MojiLearnPageState(introducedIDs: ["j-人", "j-日"], freshIDs: [], lessonsCompleted: 9, lastLessonAt: nil),
            "kanji.nope": MojiLearnPageState(introducedIDs: ["j-人"], freshIDs: [], lessonsCompleted: 1, lastLessonAt: nil)
        ])
        let restored = MojiLearnRepository.restore(stored, catalog: catalog)
        #expect(restored.state(for: .kanji(.people)) == saved)
        #expect(restored.state(for: .kanji(.time)).introducedIDs == ["j-日"])
        #expect(restored.state(for: .kanji(.time)).lastLessonAt == nil)
        #expect(restored.pages["kanji.nope"] == nil)
    }

    @Test("A broken file costs only itself")
    func brokenFileIsContained() async throws {
        let directory = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try write(#"{"oops":true}"#, to: "practice.sessions.json", in: directory)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("practice.answer_modes.json"))
        try write(#"{"j-人":{"strength":4,"seen":4,"correct":4,"lastSeenAt":0}}"#, to: "practice.progress.json", in: directory)
        try write(#"{"scripts":{"kanji":"nonsense"}}"#, to: "learn.state.json", in: directory)

        let snapshot = await practice(at: directory).activate()
        #expect(snapshot.sessions.isEmpty)
        #expect(snapshot.answerModes.isEmpty)
        #expect(snapshot.progress["j-人"]?.strength == 4)
        #expect(await learn(at: directory).activate().state == .empty)
    }
}
