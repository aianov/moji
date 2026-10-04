import Foundation
import Testing
@testable import Moji

@Suite("Practice repository")
struct MojiPracticeRepositoryTests {
    private let catalog = MojiAlphabetCatalog.shared

    private func makeRepository(at directory: URL) -> MojiPracticeRepository {
        MojiPracticeRepository(
            resources: MojiPracticeResourceRepository(store: MojiDiskStore(directory: directory)),
            catalog: catalog
        )
    }

    private func scratchDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("moji-tests-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("A full pass completes once, resumes after a restart and lights today")
    func fullPass() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = makeRepository(at: directory)
        _ = await repository.activate()
        let session = try #require(await repository.startSession(page: .katakana, now: Date()))
        let resumed = await repository.startSession(page: .katakana, now: Date())
        #expect(resumed?.id == session.id)

        var current = session
        var asked: Set<String> = []
        var completion: MojiPracticeCompletion?
        var index = 0

        while completion == nil {
            let question = try #require(current.current)
            #expect(!asked.contains(question.characterID))
            asked.insert(question.characterID)

            let outcome = await repository.answer(
                MojiAnswerSubmission(
                    page: .katakana,
                    sessionID: session.id,
                    questionIndex: index,
                    chosenID: question.characterID,
                    thinkSeconds: 1,
                    answeredAt: Date()
                )
            )
            switch try #require(outcome) {
            case .next(let next):
                current = next
            case .completed(let done):
                completion = done
            }
            index += 1

            if index == 20 {
                let reloaded = makeRepository(at: directory)
                let snapshot = await reloaded.activate()
                #expect(snapshot.sessions[.katakana]?.answeredCount == 20)
                #expect(snapshot.sessions[.katakana]?.current == current.current)
            }
        }

        let done = try #require(completion)
        #expect(done.record.total == catalog.pool(.katakana).count)
        #expect(done.record.correct == done.record.total)
        #expect(done.record.page == .katakana)
        #expect(done.extendedStreak)
        #expect(done.streak == 1)

        let snapshot = await makeRepository(at: directory).activate()
        #expect(snapshot.sessions.isEmpty)
        #expect(snapshot.activity.isTodayDone)
        #expect(snapshot.activity.pagesDoneToday == [.katakana])
    }

    @Test("A kanji theme is a page of its own: its session, its stats")
    func kanjiThemeSession() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = makeRepository(at: directory)
        let people = try #require(await repository.startSession(page: .kanji(.people), now: Date()))
        let time = try #require(await repository.startSession(page: .kanji(.time), now: Date()))
        #expect(people.id != time.id)
        #expect(Set(people.order) == Set(catalog.pool(.kanji(.people)).map(\.id)))
        #expect(Set(time.order) == Set(catalog.pool(.kanji(.time)).map(\.id)))

        let question = try #require(people.current)
        _ = await repository.answer(
            MojiAnswerSubmission(
                page: .kanji(.people),
                sessionID: people.id,
                questionIndex: 0,
                chosenID: question.characterID,
                thinkSeconds: 1,
                answeredAt: Date()
            )
        )
        let misdirected = await repository.answer(
            MojiAnswerSubmission(
                page: .kanji(.time),
                sessionID: people.id,
                questionIndex: 1,
                chosenID: nil,
                thinkSeconds: 1,
                answeredAt: Date()
            )
        )
        #expect(misdirected == nil)

        let snapshot = await makeRepository(at: directory).activate()
        #expect(snapshot.sessions[.kanji(.people)]?.answeredCount == 1)
        #expect(snapshot.sessions[.kanji(.time)]?.answeredCount == 0)
        #expect(snapshot.pageStats[.kanji(.people)]?.practiced == 1)
        #expect(snapshot.pageStats[.kanji(.time)]?.practiced == 0)
        #expect(snapshot.pageStats[.kanji(.people)]?.total == catalog.pool(.kanji(.people)).count)
    }

    @Test("A stale or repeated answer is ignored")
    func staleAnswerIsIgnored() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = makeRepository(at: directory)
        let session = try #require(await repository.startSession(page: .hiragana, now: Date()))
        let question = try #require(session.current)
        let submission = MojiAnswerSubmission(
            page: .hiragana,
            sessionID: session.id,
            questionIndex: 0,
            chosenID: question.characterID,
            thinkSeconds: 1,
            answeredAt: Date()
        )

        #expect(await repository.answer(submission) != nil)
        #expect(await repository.answer(submission) == nil)
    }

    @Test("Discard and reset remove what they should")
    func discardAndReset() async throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = makeRepository(at: directory)
        _ = try #require(await repository.startSession(page: .kanji(.people), now: Date()))
        _ = try #require(await repository.startSession(page: .kanji(.names), now: Date()))
        await repository.discardSession(page: .kanji(.people))
        let afterDiscard = await repository.activate()
        #expect(afterDiscard.sessions[.kanji(.people)] == nil)
        #expect(afterDiscard.sessions[.kanji(.names)] != nil)

        _ = try #require(await repository.startSession(page: .kanji(.oldForms), now: Date()))
        await repository.resetAll()
        let snapshot = await makeRepository(at: directory).activate()
        #expect(snapshot.sessions.isEmpty)
        #expect(snapshot.progress.isEmpty)
        #expect(snapshot.activity.totalSessions == 0)
    }
}
