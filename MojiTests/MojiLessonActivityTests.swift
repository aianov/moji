import Foundation
import Testing
@testable import Moji

@Suite("Lessons in the activity log")
struct MojiLessonActivityTests {
    private func makeRepository(at directory: URL) -> MojiPracticeRepository {
        MojiPracticeRepository(
            resources: MojiPracticeResourceRepository(store: MojiDiskStore(directory: directory)),
            catalog: MojiAlphabetCatalog.shared
        )
    }

    private func scratchDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("moji-tests-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("The first lesson of the day lights it; the second one only adds to the count")
    func lessonLightsTheDay() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = makeRepository(at: directory)
        let before = await repository.activate()
        #expect(!before.activity.isTodayDone)

        let now = Date()
        let first = await repository.recordLesson(
            page: .hiragana,
            total: 14,
            correct: 12,
            startedAt: now.addingTimeInterval(-180),
            at: now
        )
        #expect(first.extendedStreak)
        #expect(first.streak == 1)
        #expect(first.record.isLesson)
        #expect(first.record.activeSeconds >= 179)

        let second = await repository.recordLesson(
            page: .katakana,
            total: 12,
            correct: 12,
            startedAt: now,
            at: now.addingTimeInterval(60)
        )
        #expect(!second.extendedStreak)
        #expect(second.streak == 1)

        let reloaded = await makeRepository(at: directory).activate()
        #expect(reloaded.activity.isTodayDone)
        #expect(reloaded.activity.totalSessions == 2)
        #expect(reloaded.activity.pagesDoneToday == [.hiragana, .katakana])
    }

    @Test("Each kanji theme counts as its own page done today")
    func kanjiThemesAreSeparatePages() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = makeRepository(at: directory)
        let now = Date()
        let lesson = await repository.recordLesson(
            page: .kanji(.people),
            total: 13,
            correct: 13,
            startedAt: now.addingTimeInterval(-120),
            at: now
        )
        #expect(lesson.page == .kanji(.people))
        #expect(lesson.record.page == .kanji(.people))
        #expect(lesson.record.script == .kanji)
        _ = await repository.recordLesson(
            page: .kanji(.oldForms),
            total: 12,
            correct: 10,
            startedAt: now,
            at: now.addingTimeInterval(30)
        )

        let reloaded = await makeRepository(at: directory).activate()
        #expect(reloaded.activity.pagesDoneToday == [.kanji(.people), .kanji(.oldForms)])
        #expect(reloaded.activity.totalSessions == 2)
    }

    @Test("A record saved before lessons existed reads back as a session")
    func oldRecordsAreSessions() throws {
        let json = """
        {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","script":"hiragana","dayKey":"2026-10-03",
         "startedAt":0,"completedAt":60,"total":115,"correct":110,"bestCombo":30,
         "activeSeconds":60,"mistakeIDs":["h-nu"]}
        """
        let record = try JSONDecoder().decode(MojiCompletedSession.self, from: Data(json.utf8))
        #expect(record.kind == nil)
        #expect(!record.isLesson)
        #expect(record.page == .hiragana)
        #expect(record.script == .hiragana)
    }

    @Test("A record round-trips with its page")
    func recordKeepsItsPage() throws {
        let record = MojiCompletedSession(
            id: UUID(),
            page: .kanji(.oldForms),
            script: .kanji,
            dayKey: "2026-10-04",
            startedAt: Date(timeIntervalSince1970: 0),
            completedAt: Date(timeIntervalSince1970: 60),
            total: 12,
            correct: 11,
            bestCombo: 0,
            activeSeconds: 60,
            mistakeIDs: [],
            kind: .lesson
        )
        let data = try JSONEncoder().encode(record)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"page\":\"kanji.old_forms\""))
        #expect(text.contains("\"script\":\"kanji\""))
        #expect(try JSONDecoder().decode(MojiCompletedSession.self, from: data) == record)
    }
}
