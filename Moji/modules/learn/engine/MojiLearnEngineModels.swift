import Foundation

struct MojiLearnPageState: Codable, Equatable, Sendable {
    var introducedIDs: [String]
    var freshIDs: [String]
    var lessonsCompleted: Int
    var lastLessonAt: Date?
    var writtenBatchIDs: [String] = []

    enum CodingKeys: String, CodingKey {
        case introducedIDs
        case freshIDs
        case lessonsCompleted
        case lastLessonAt
        case writtenBatchIDs
    }

    static let empty = MojiLearnPageState(
        introducedIDs: [],
        freshIDs: [],
        lessonsCompleted: 0,
        lastLessonAt: nil
    )

    func completing(_ lesson: MojiLesson, at date: Date) -> MojiLearnPageState {
        var known = Set(introducedIDs)
        var introduced = introducedIDs
        for id in lesson.coveredCharacterIDs where known.insert(id).inserted {
            introduced.append(id)
        }
        let covered = Set(lesson.coveredCharacterIDs)
        return MojiLearnPageState(
            introducedIDs: introduced,
            freshIDs: freshIDs.filter { !covered.contains($0) } + lesson.newCharacterIDs,
            lessonsCompleted: lessonsCompleted + 1,
            lastLessonAt: date,
            writtenBatchIDs: writtenBatchIDs
        )
    }

    func writing(_ batchID: String) -> MojiLearnPageState {
        guard !writtenBatchIDs.contains(batchID) else { return self }
        var result = self
        result.writtenBatchIDs.append(batchID)
        return result
    }
}

extension MojiLearnPageState {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            introducedIDs: try container.decode([String].self, forKey: .introducedIDs),
            freshIDs: try container.decode([String].self, forKey: .freshIDs),
            lessonsCompleted: try container.decode(Int.self, forKey: .lessonsCompleted),
            lastLessonAt: try container.decodeIfPresent(Date.self, forKey: .lastLessonAt),
            writtenBatchIDs: try container.decodeIfPresent([String].self, forKey: .writtenBatchIDs) ?? []
        )
    }
}

struct MojiLearnState: Codable, Equatable, Sendable {
    var pages: [String: MojiLearnPageState]

    enum CodingKeys: String, CodingKey {
        case pages = "scripts"
    }

    static let empty = MojiLearnState(pages: [:])

    func state(for page: MojiPage) -> MojiLearnPageState {
        pages[page.rawValue] ?? .empty
    }
}

struct MojiLearnBatch: Identifiable, Equatable, Sendable {
    let id: String
    let index: Int
    let page: MojiPage
    let sectionID: String
    let characterIDs: [String]
}

enum MojiLearnBatchStatus: String, Equatable, Sendable {
    case learned
    case current
    case review
    case new
}

struct MojiLearnBatchState: Identifiable, Equatable, Sendable {
    let batch: MojiLearnBatch
    let status: MojiLearnBatchStatus
    let mastery: Double

    var id: String { batch.id }
}

struct MojiLearnPath: Equatable, Sendable {
    let page: MojiPage
    let batches: [MojiLearnBatchState]
    let currentIndex: Int?

    var learnedCount: Int {
        batches.filter { $0.status == .learned }.count
    }

    var isComplete: Bool {
        !batches.isEmpty && batches.allSatisfy { $0.status == .learned }
    }

    var current: MojiLearnBatchState? {
        currentIndex.flatMap { batches.indices.contains($0) ? batches[$0] : nil }
    }
}

enum MojiLessonDirection: Equatable, Sendable {
    case glyphToAnswer
    case answerToGlyph
}

enum MojiLessonWordMode: Equatable, Sendable {
    case type
    case choose(options: [[String]])
}

enum MojiLessonStepKind: String, Equatable, Sendable {
    case intro
    case choice
    case listen
    case match
    case write
    case word
    case read
}

enum MojiLessonStep: Equatable, Sendable {
    case intro(characterID: String)
    case choice(characterID: String, direction: MojiLessonDirection, optionIDs: [String])
    case listen(characterID: String, optionIDs: [String])
    case match(leftIDs: [String], rightIDs: [String])
    case write(batchID: String, characterIDs: [String])
    case word(characterIDs: [String], mode: MojiLessonWordMode)
    case read(characterIDs: [String])

    var kind: MojiLessonStepKind {
        switch self {
        case .intro: .intro
        case .choice: .choice
        case .listen: .listen
        case .match: .match
        case .write: .write
        case .word: .word
        case .read: .read
        }
    }

    var characterIDs: [String] {
        switch self {
        case .intro(let id), .choice(let id, _, _), .listen(let id, _):
            [id]
        case .match(let leftIDs, _):
            leftIDs
        case .write(_, let ids), .word(let ids, _), .read(let ids):
            ids
        }
    }
}

struct MojiLessonItem: Equatable, Sendable {
    let step: MojiLessonStep
    var isHard: Bool = false
    var isRetry: Bool = false
}

struct MojiLesson: Identifiable, Equatable, Sendable {
    let id: UUID
    let page: MojiPage
    let batchIndex: Int?
    let newCharacterIDs: [String]
    let reviewCharacterIDs: [String]
    let items: [MojiLessonItem]

    var isReview: Bool {
        batchIndex == nil
    }

    var coveredCharacterIDs: [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        for item in items {
            for id in item.step.characterIDs where seen.insert(id).inserted {
                ordered.append(id)
            }
        }
        return ordered
    }
}

struct MojiLessonAnswer: Equatable, Sendable {
    let characterID: String
    let isCorrect: Bool
    var steps: Int = 1
}
