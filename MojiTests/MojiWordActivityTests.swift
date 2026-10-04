import Foundation
import Testing
@testable import Moji

@Suite("Words sessions in the activity log")
struct MojiWordActivityTests {
    private func practice(at directory: URL) -> MojiPracticeRepository {
        MojiPracticeRepository(
            resources: MojiPracticeResourceRepository(store: MojiDiskStore(directory: directory)),
            catalog: MojiAlphabetCatalog.shared
        )
    }

    private func record(script: String, page: String?, kind: String?) -> String {
        let pageField = page.map { #","page":""# + $0 + "\"" } ?? ""
        let kindField = kind.map { #","kind":""# + $0 + "\"" } ?? ""
        return #"{"activeSeconds":60,"bestCombo":0,"completedAt":60,"correct":10,"dayKey":"2026-10-03","id":""#
            + UUID().uuidString + #"","mistakeIDs":[],"script":""# + script + #"","startedAt":0,"total":12"#
            + pageField + kindField + "}"
    }

    @Test("Old logs still decode: no kind, lessons, words, and a kind from the future")
    func oldLogs() throws {
        let entries = [
            record(script: "hiragana", page: nil, kind: nil),
            record(script: "kanji", page: "kanji.people", kind: "lesson"),
            record(script: "kanji", page: nil, kind: "words"),
            record(script: "katakana", page: "katakana", kind: "flashcards")
        ]
        let json = #"{"completed":["# + entries.joined(separator: ",") + "]}"
        let log = try JSONDecoder().decode(MojiActivityLog.self, from: Data(json.utf8))
        #expect(log.completed.count == 4)
        #expect(log.completed[0].kind == nil)
        #expect(log.completed[0].page == .hiragana)
        #expect(log.completed[1].kind == .lesson)
        #expect(log.completed[2].kind == .words)
        #expect(log.completed[2].page == nil)
        #expect(log.completed[3].kind == nil)
        #expect(log.completed[3].page == .katakana)
    }

    @Test("A words record keeps no page through a save and a load")
    func wordsRecordRoundTrip() throws {
        let record = MojiCompletedSession(
            id: UUID(),
            page: nil,
            script: .kanji,
            dayKey: "2026-10-04",
            startedAt: Date(timeIntervalSince1970: 0),
            completedAt: Date(timeIntervalSince1970: 300),
            total: 40,
            correct: 35,
            bestCombo: 0,
            activeSeconds: 280,
            mistakeIDs: [],
            kind: .words
        )
        let data = try JSONEncoder().encode(record)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"kind\":\"words\""))
        #expect(!text.contains("\"page\""))
        let decoded = try JSONDecoder().decode(MojiCompletedSession.self, from: data)
        #expect(decoded == record)
        #expect(decoded.page == nil)
        #expect(!decoded.isLesson)
    }

    @Test("A finished words session lights the day without marking any page as done")
    func wordsSessionLightsTheDay() async throws {
        let directory = MojiWordTestSupport.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = practice(at: directory)
        #expect(!(await repository.activate()).activity.isTodayDone)

        let now = Date()
        let first = await repository.recordWordsSession(
            total: 30,
            correct: 26,
            startedAt: now.addingTimeInterval(-400),
            activeSeconds: 380,
            at: now
        )
        #expect(first.extendedStreak)
        #expect(first.streak == 1)
        #expect(first.record.kind == .words)
        #expect(first.record.page == nil)
        #expect(first.record.activeSeconds == 380)

        let second = await repository.recordWordsSession(
            total: 5,
            correct: 9,
            startedAt: now,
            activeSeconds: -3,
            at: now.addingTimeInterval(30)
        )
        #expect(!second.extendedStreak)
        #expect(second.record.correct == 5)
        #expect(second.record.activeSeconds == 0)

        let reloaded = await practice(at: directory).activate()
        #expect(reloaded.activity.isTodayDone)
        #expect(reloaded.activity.totalSessions == 2)
        #expect(reloaded.activity.pagesDoneToday.isEmpty)
        #expect(reloaded.activity.currentStreak == 1)
        #expect(reloaded.activity.dayCounts[reloaded.activity.todayKey] == 2)
    }
}
