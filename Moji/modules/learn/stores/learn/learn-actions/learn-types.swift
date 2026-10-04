import Foundation

struct LearnPresentedLesson: Identifiable, Equatable {
    let page: MojiPage
    let token: UUID

    var id: UUID { token }
}

enum LearnStage: Equatable {
    case loading
    case exercise(LessonExerciseModel)
    case writingNotice(LessonSummaryModel)
    case finished(LessonSummaryModel)
    case unavailable
}

enum LessonContent: Equatable {
    case intro(MojiCharacter)
    case choice(prompt: MojiCharacter, direction: MojiLessonDirection, options: [MojiCharacter])
    case listen(answer: MojiCharacter, options: [MojiCharacter])
    case match(left: [MojiCharacter], right: [MojiCharacter])
    case word(characters: [MojiCharacter], options: [[MojiCharacter]]?)
    case read(characters: [MojiCharacter])
}

struct LessonExerciseModel: Identifiable, Equatable {
    let lessonID: UUID
    let page: MojiPage
    let position: Int
    let item: MojiLessonItem
    let content: LessonContent

    var id: String {
        "\(lessonID.uuidString)#\(position)"
    }

    var isHard: Bool { item.isHard }
    var isRetry: Bool { item.isRetry }
    var kind: MojiLessonStepKind { item.step.kind }

    static func make(
        lessonID: UUID,
        page: MojiPage,
        position: Int,
        item: MojiLessonItem,
        catalog: MojiAlphabetCatalog
    ) -> LessonExerciseModel? {
        func resolve(_ ids: [String]) -> [MojiCharacter]? {
            let characters = ids.compactMap { catalog.character($0) }
            return characters.count == ids.count ? characters : nil
        }

        let content: LessonContent
        switch item.step {
        case .intro(let id):
            guard let character = catalog.character(id) else { return nil }
            content = .intro(character)
        case .choice(let id, let direction, let optionIDs):
            guard let prompt = catalog.character(id), let options = resolve(optionIDs) else { return nil }
            content = .choice(prompt: prompt, direction: direction, options: options)
        case .listen(let id, let optionIDs):
            guard let answer = catalog.character(id), let options = resolve(optionIDs) else { return nil }
            content = .listen(answer: answer, options: options)
        case .match(let leftIDs, let rightIDs):
            guard let left = resolve(leftIDs), let right = resolve(rightIDs) else { return nil }
            content = .match(left: left, right: right)
        case .word(let ids, .type):
            guard let characters = resolve(ids) else { return nil }
            content = .word(characters: characters, options: nil)
        case .word(let ids, .choose(let optionIDs)):
            guard let characters = resolve(ids) else { return nil }
            let options = optionIDs.compactMap(resolve)
            guard options.count == optionIDs.count else { return nil }
            content = .word(characters: characters, options: options)
        case .read(let ids):
            guard let characters = resolve(ids) else { return nil }
            content = .read(characters: characters)
        }

        return LessonExerciseModel(
            lessonID: lessonID,
            page: page,
            position: position,
            item: item,
            content: content
        )
    }
}

struct LessonFeedback: Equatable {
    let isCorrect: Bool
    let title: String
    let detail: String?
}

struct LessonMatchShake: Equatable {
    let ids: Set<String>
    let token: Int
}

struct LessonSummaryCharacter: Identifiable, Equatable {
    let character: MojiCharacter
    let strength: Int
    let isNew: Bool
    var isWritten = false

    var id: String { character.id }

    var mastery: Double {
        MojiCharacterProgress.mastery(strength: strength, isWritten: isWritten)
    }
}

enum LessonSummaryNext: Equatable {
    case batch(number: Int, characters: [MojiCharacter])
    case sameBatch
    case allLearned
}

struct LessonSummaryModel: Equatable {
    let page: MojiPage
    let isReview: Bool
    let batchNumber: Int?
    let batchCount: Int
    let answered: Int
    let correct: Int
    let hardDone: Int
    let characters: [LessonSummaryCharacter]
    let next: LessonSummaryNext
    let streakDay: Int?

    var accuracy: Double {
        answered > 0 ? Double(correct) / Double(answered) : 1
    }
}

struct LearnPathSection: Identifiable, Equatable {
    let id: String
    let title: String?
    var batches: [MojiLearnBatchState]
}

struct LearnBulkMark: Identifiable, Equatable {
    let title: String
    let characterIDs: [String]
    let isWholeScript: Bool

    var id: String { "\(title)#\(characterIDs.count)" }
}

struct LearnWritingPractice: Identifiable, Equatable {
    let batch: MojiLearnBatch
    let request: WritingPracticeRequest

    var id: UUID { request.id }
}
