import Foundation
import Testing
@testable import Moji

@Suite("Writing completes mastery")
struct MojiWritingMasteryTests {
    private let catalog = MojiAlphabetCatalog.shared
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func entry(strength: Int, writtenAt: Date? = nil) -> MojiCharacterProgress {
        MojiCharacterProgress(strength: strength, seen: 6, correct: 5, lastSeenAt: now, writtenAt: writtenAt)
    }

    @Test("Answers fill 80%, finished writing adds the last fixed 20%")
    func masteryShares() {
        #expect(abs(entry(strength: 5).mastery - 0.8) < 1e-9)
        #expect(abs(entry(strength: 5, writtenAt: now).mastery - 1) < 1e-9)
        #expect(abs(entry(strength: 0, writtenAt: now).mastery - 0.2) < 1e-9)
        #expect(abs(entry(strength: 3).mastery - 0.48) < 1e-9)
        #expect(entry(strength: 9).recognition == 1)
    }

    @Test("Gold needs both: every answer step and finished writing")
    func goldNeedsWriting() {
        #expect(!entry(strength: 5).isMastered)
        #expect(entry(strength: 5).isRecognized)
        #expect(!entry(strength: 4, writtenAt: now).isMastered)
        #expect(entry(strength: 5, writtenAt: now).isMastered)
    }

    @Test("Answers keep the written mark, and writing again keeps the first date")
    func writtenMarkSticks() {
        let written = entry(strength: 2).writing(at: now)
        #expect(written.writtenAt == now)
        #expect(written.writing(at: now.addingTimeInterval(60)).writtenAt == now)
        #expect(written.recording(correct: false, at: now.addingTimeInterval(120)).isWritten)
        #expect(written.recording(correct: true, at: now.addingTimeInterval(180), steps: 2).isWritten)
    }

    @Test("Progress saved before writing existed loads unwritten")
    func oldProgressLoads() throws {
        let json = Data(#"{"strength":5,"seen":7,"correct":6,"lastSeenAt":800000000}"#.utf8)
        let decoded = try JSONDecoder().decode(MojiCharacterProgress.self, from: json)
        #expect(decoded.strength == 5)
        #expect(!decoded.isWritten)
        #expect(abs(decoded.mastery - 0.8) < 1e-9)
    }

    @Test("A group fills to 100% only once its characters are written")
    func groupFill() throws {
        let planner = MojiLearnPlanner(catalog: catalog)
        let batch = try #require(planner.batches(.hiragana).first)
        var progress: [String: MojiCharacterProgress] = [:]
        for id in batch.characterIDs {
            progress[id] = entry(strength: 5)
        }
        let state = MojiLearnPageState(introducedIDs: batch.characterIDs, freshIDs: [], lessonsCompleted: 2, lastLessonAt: now)
        let recognized = planner.path(page: .hiragana, progress: progress, state: state).batches[0]
        #expect(recognized.status == .learned)
        #expect(abs(recognized.mastery - 0.8) < 1e-9)

        for id in batch.characterIDs {
            progress[id] = entry(strength: 5, writtenAt: now)
        }
        let written = planner.path(page: .hiragana, progress: progress, state: state).batches[0]
        #expect(abs(written.mastery - 1) < 1e-9)
    }

    @Test("Finished writing is saved and survives a restart")
    func writtenPersists() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("moji-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        func repository() -> MojiPracticeRepository {
            MojiPracticeRepository(
                resources: MojiPracticeResourceRepository(store: MojiDiskStore(directory: directory)),
                catalog: catalog
            )
        }

        let first = repository()
        _ = await first.activate()
        await first.recordAnswer(characterID: "h-a", correct: true, at: now)
        await first.markWritten(["h-a", "h-i", "nope"], at: now)
        await first.markWritten(["h-a"], at: now.addingTimeInterval(60))

        let reloaded = await repository().activate()
        #expect(reloaded.progress["h-a"]?.writtenAt == now)
        #expect(reloaded.progress["h-a"]?.strength == 1)
        #expect(reloaded.progress["h-i"]?.isWritten == true)
        #expect(reloaded.progress["h-i"]?.strength == 0)
        #expect(reloaded.progress["nope"] == nil)
    }
}
