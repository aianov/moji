import Foundation
import Testing
@testable import Moji

private struct WritingLessonGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

@Suite("Writing in lessons")
struct MojiLearnWritingTests {
    private let catalog = MojiAlphabetCatalog.shared
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func planner() throws -> MojiLearnPlanner {
        let library: MojiStrokeLibrary = try #require(WritingFixture.library)
        return MojiLearnPlanner(catalog: catalog, strokes: library)
    }

    private func progress(_ ids: [String], strength: Int) -> [String: MojiCharacterProgress] {
        var result: [String: MojiCharacterProgress] = [:]
        for id in ids {
            result[id] = MojiCharacterProgress(
                strength: strength,
                seen: max(strength, 1),
                correct: strength,
                lastSeenAt: now.addingTimeInterval(-86_400)
            )
        }
        return result
    }

    private func state(
        introduced ids: [String],
        fresh: [String] = [],
        written: [String] = []
    ) -> MojiLearnPageState {
        MojiLearnPageState(
            introducedIDs: ids,
            freshIDs: fresh,
            lessonsCompleted: 1,
            lastLessonAt: now,
            writtenBatchIDs: written
        )
    }

    private func lesson(
        _ planner: MojiLearnPlanner,
        _ page: MojiPage,
        progress: [String: MojiCharacterProgress],
        state: MojiLearnPageState,
        batchIndex: Int? = nil,
        seed: UInt64 = 1
    ) throws -> MojiLesson {
        var generator = WritingLessonGenerator(state: seed)
        return try #require(
            planner.makeLesson(
                page: page,
                progress: progress,
                state: state,
                now: now,
                batchIndex: batchIndex,
                using: &generator
            )
        )
    }

    private func writing(_ lesson: MojiLesson) -> (batchID: String, ids: [String])? {
        let steps = lesson.items.compactMap { item -> (String, [String])? in
            guard case .write(let batchID, let ids) = item.step else { return nil }
            return (batchID, ids)
        }
        guard steps.count == 1, case .write = lesson.items.last?.step else { return nil }
        return steps.first.map { (batchID: $0.0, ids: $0.1) }
    }

    private func writeSteps(_ lesson: MojiLesson) -> Int {
        lesson.items.filter { $0.step.kind == .write }.count
    }

    @Test("The lesson that introduces a group never asks to write it", arguments: [MojiPage.hiragana, .katakana, .kanji(.people)])
    func introducingLesson(page: MojiPage) throws {
        let planner = try planner()
        for seed in 1...5 {
            let first = try lesson(planner, page, progress: [:], state: .empty, seed: UInt64(seed))
            #expect(!first.newCharacterIDs.isEmpty)
            #expect(writeSteps(first) == 0)

            let picked = try lesson(planner, page, progress: [:], state: .empty, batchIndex: 3, seed: UInt64(seed))
            #expect(picked.batchIndex == 3)
            #expect(writeSteps(picked) == 0)
        }
    }

    @Test("The next lesson on a group ends with writing the whole group", arguments: [MojiPage.hiragana, .katakana, .kanji(.people)])
    func nextLessonWrites(page: MojiPage) throws {
        let planner = try planner()
        let batch = planner.batches(page)[0]
        let members = batch.characterIDs
        for seed in 1...10 {
            let next = try lesson(
                planner,
                page,
                progress: progress(members, strength: 2),
                state: state(introduced: members, fresh: members),
                seed: UInt64(seed)
            )
            #expect(next.batchIndex == 0)
            #expect(next.newCharacterIDs.isEmpty)
            let step = try #require(writing(next), "seed \(seed)")
            #expect(step.batchID == batch.id)
            #expect(step.ids == members)
            #expect(MojiLearnPlanner.lessonLength.contains(next.items.count))
        }
    }

    @Test("A good second lesson makes the block due by the time it is reached")
    func dueAtTheEndOfTheSecondLesson() throws {
        let planner = try planner()
        let batch = planner.batches(.hiragana)[0]
        let members = batch.characterIDs
        let before = progress(members, strength: 2)
        for seed in 1...5 {
            let second = try lesson(
                planner,
                .hiragana,
                progress: before,
                state: state(introduced: members, fresh: members),
                seed: UInt64(seed)
            )
            let step = try #require(writing(second))
            #expect(!planner.isWritingDue(step.batchID, on: .hiragana, progress: before))

            let answers = second.items.dropLast().flatMap { item in
                item.step.characterIDs.filter(members.contains).map {
                    MojiLessonAnswer(characterID: $0, isCorrect: true)
                }
            }
            let after = MojiLearnPlanner.applying(answers, to: before, at: now)
            #expect(planner.isWritingDue(step.batchID, on: .hiragana, progress: after), "seed \(seed)")
        }
    }

    @Test("A group that is written already is not asked again")
    func writtenGroupIsLeftAlone() throws {
        let planner = try planner()
        let batch = planner.batches(.hiragana)[0]
        let members = batch.characterIDs
        let next = try lesson(
            planner,
            .hiragana,
            progress: progress(members, strength: 3),
            state: state(introduced: members, fresh: members, written: [batch.id])
        )
        #expect(next.batchIndex == 0)
        #expect(writeSteps(next) == 0)
        #expect(MojiLearnPlanner.lessonLength.contains(next.items.count))
    }

    @Test("A group picked from the list ends with writing it, unless it is new", arguments: [MojiPage.hiragana, .kanji(.time)])
    func pickedGroup(page: MojiPage) throws {
        let planner = try planner()
        let batches = planner.batches(page)
        let learned = batches.prefix(3).flatMap(\.characterIDs)
        let entries = progress(learned, strength: 4)
        let introduced = state(introduced: learned)
        #expect(planner.path(page: page, progress: entries, state: introduced).batches[1].status == .learned)

        for seed in 1...5 {
            let again = try lesson(planner, page, progress: entries, state: introduced, batchIndex: 1, seed: UInt64(seed))
            let step = try #require(writing(again))
            #expect(step.batchID == batches[1].id)
            #expect(step.ids == batches[1].characterIDs)
            #expect(MojiLearnPlanner.lessonLength.contains(again.items.count))

            let fresh = try lesson(planner, page, progress: entries, state: introduced, batchIndex: 6, seed: UInt64(seed))
            #expect(fresh.newCharacterIDs == batches[6].characterIDs)
            #expect(writeSteps(fresh) == 0)
        }

        let written = try lesson(
            planner,
            page,
            progress: entries,
            state: state(introduced: learned, written: [batches[1].id]),
            batchIndex: 1
        )
        #expect(writeSteps(written) == 0)
    }

    @Test("Review lessons never ask to write")
    func reviewLessons() throws {
        let planner = try planner()
        let all = catalog.pool(.katakana).map(\.id)
        let marked = progress(all, strength: MojiCharacterProgress.masteryLevel)
        for seed in 1...5 {
            let review = try lesson(planner, .katakana, progress: marked, state: .empty, seed: UInt64(seed))
            #expect(review.isReview)
            #expect(writeSteps(review) == 0)
        }
    }

    @Test("Characters without stroke data are left out of the block")
    func oldFormsWithoutStrokes() throws {
        let planner = try planner()
        let library = try #require(WritingFixture.library)
        let page = MojiPage.kanji(.oldForms)
        let batch = planner.batches(page)[6]
        let glyphs = batch.characterIDs.compactMap { catalog.character($0)?.glyph }
        #expect(glyphs.contains("擊"))
        let writable = batch.characterIDs.filter { id in
            catalog.character(id).map { library.canWrite($0.glyph) } ?? false
        }
        #expect(!writable.isEmpty && writable.count < batch.characterIDs.count)

        let learned = planner.batches(page).prefix(7).flatMap(\.characterIDs)
        let picked = try lesson(
            planner,
            page,
            progress: progress(learned, strength: 4),
            state: state(introduced: learned),
            batchIndex: 6
        )
        let step = try #require(writing(picked))
        #expect(step.ids == writable)
        #expect(step.ids.allSatisfy(planner.canWrite))
    }

    @Test("Without stroke data no lesson asks to write")
    func noStrokeData() throws {
        let bare = MojiLearnPlanner(catalog: catalog)
        let batch = bare.batches(.hiragana)[0]
        let next = try lesson(
            bare,
            .hiragana,
            progress: progress(batch.characterIDs, strength: 3),
            state: state(introduced: batch.characterIDs, fresh: batch.characterIDs)
        )
        #expect(writeSteps(next) == 0)
        #expect(!bare.canWrite(batch.characterIDs[0]))
    }

    @Test("The block is due once the group is recognized: average 3, none below 2")
    func writingIsDue() throws {
        let planner = try planner()
        let batch = planner.batches(.hiragana)[0]
        let ids = batch.characterIDs
        func due(_ strengths: [Int]) -> Bool {
            var entries: [String: MojiCharacterProgress] = [:]
            for (id, strength) in zip(ids, strengths) {
                entries[id] = MojiCharacterProgress(strength: strength, seen: 5, correct: strength, lastSeenAt: now)
            }
            return planner.isWritingDue(batch.id, on: .hiragana, progress: entries)
        }
        #expect(ids.count == 5)
        #expect(due([3, 3, 3, 3, 3]))
        #expect(due([4, 2, 3, 3, 3]))
        #expect(!due([5, 5, 5, 5, 1]))
        #expect(!due([2, 2, 2, 2, 2]))
        #expect(!due([]))
        #expect(!planner.isWritingDue("hiragana.nope#0", on: .hiragana, progress: [:]))
    }

    @Test("A retry of the writing step is the same step")
    func retryKeepsTheBlock() throws {
        let planner = try planner()
        let batch = planner.batches(.hiragana)[0]
        let item = MojiLessonItem(step: .write(batchID: batch.id, characterIDs: batch.characterIDs))
        var generator = WritingLessonGenerator(state: 4)
        let retry = planner.retry(of: item, using: &generator)
        #expect(retry.step == item.step)
        #expect(item.step.characterIDs == batch.characterIDs)
        #expect(item.step.kind == .write)
    }

    @Test("Written groups are saved with the page, old saves load without any")
    func writtenGroupsAreSaved() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970

        let old = #"{"introducedIDs":["h-a"],"freshIDs":[],"lessonsCompleted":2,"lastLessonAt":50}"#
        let loaded = try decoder.decode(MojiLearnPageState.self, from: Data(old.utf8))
        #expect(loaded.writtenBatchIDs.isEmpty)
        #expect(loaded.introducedIDs == ["h-a"])
        #expect(loaded.lessonsCompleted == 2)

        let written = loaded.writing("hiragana.basic#0")
        #expect(written.writtenBatchIDs == ["hiragana.basic#0"])
        #expect(written.writing("hiragana.basic#0") == written)

        let again = try decoder.decode(MojiLearnPageState.self, from: try encoder.encode(written))
        #expect(again == written)

        let planner = try planner()
        let lesson = try lesson(planner, .hiragana, progress: [:], state: .empty)
        #expect(written.completing(lesson, at: now).writtenBatchIDs == ["hiragana.basic#0"])
    }

    @Test("Marking a group written survives a restart")
    func markWrittenPersists() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("moji-writing-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        func repository() -> MojiLearnRepository {
            MojiLearnRepository(
                resources: MojiLearnResourceRepository(store: MojiDiskStore(directory: directory)),
                planner: .shared
            )
        }

        let batchID = MojiLearnPlanner.shared.batches(.kanji(.people))[2].id
        let first = repository()
        _ = await first.activate()
        await first.markWritten(batchID, on: .kanji(.people))
        await first.markWritten(batchID, on: .kanji(.people))

        let reloaded = await repository().activate()
        #expect(reloaded.state.state(for: .kanji(.people)).writtenBatchIDs == [batchID])
        #expect(reloaded.state.state(for: .kanji(.time)).writtenBatchIDs.isEmpty)
    }
}
