#if DEBUG
import SwiftUI

private enum MojiPreviewData {
    static func question(
        _ page: MojiPage,
        mode: MojiAnswerMode = .standard
    ) -> PracticeQuestionModel? {
        var generator = SystemRandomNumberGenerator()
        let composer = MojiQuizComposer(catalog: .shared)
        let order = composer.makeOrder(page: page, using: &generator)
        guard let first = order.first,
              let question = composer.makeQuestion(for: first, mode: mode, using: &generator) else {
            return nil
        }

        let session = MojiPracticeSession(
            id: UUID(),
            page: page,
            order: order,
            answers: [],
            current: question,
            combo: 4,
            bestCombo: 4,
            startedAt: Date(),
            updatedAt: Date(),
            activeSeconds: 0
        )
        return PracticeQuestionModel.make(session: session, catalog: .shared)
    }

    static func summary(_ page: MojiPage) -> PracticeSummaryModel {
        let pool = MojiAlphabetCatalog.shared.pool(page)
        return PracticeSummaryModel(
            page: page,
            total: pool.count,
            correct: pool.count - 6,
            activeSeconds: 312,
            bestCombo: 27,
            mistakes: Array(pool.prefix(6)),
            streak: 5,
            extendedStreak: true
        )
    }

    static func exercise(
        _ page: MojiPage,
        kind: MojiLessonStepKind?,
        hard: Bool = false
    ) -> LessonExerciseModel? {
        var generator = SystemRandomNumberGenerator()
        let monthAgo = Date().addingTimeInterval(-30 * 86_400)
        let progress: [String: MojiCharacterProgress] = hard
            ? Dictionary(uniqueKeysWithValues: MojiAlphabetCatalog.shared.pool(page).map {
                ($0.id, MojiCharacterProgress(strength: 3, seen: 6, correct: 5, lastSeenAt: monthAgo))
            })
            : [:]
        guard let lesson = MojiLearnPlanner.shared.makeLesson(
            page: page,
            progress: progress,
            state: .empty,
            now: Date(),
            using: &generator
        ),
            let index = lesson.items.firstIndex(where: { item in
                (kind == nil || item.step.kind == kind) && item.isHard == hard
            }) else {
            return nil
        }
        return LessonExerciseModel.make(
            lessonID: lesson.id,
            page: page,
            position: index,
            item: lesson.items[index],
            catalog: .shared
        )
    }

    static func writing(_ page: MojiPage) -> LessonExerciseModel? {
        var generator = SystemRandomNumberGenerator()
        guard let batch = MojiLearnPlanner.shared.batches(page).first else { return nil }
        let progress = Dictionary(uniqueKeysWithValues: batch.characterIDs.map {
            ($0, MojiCharacterProgress(strength: 3, seen: 4, correct: 4, lastSeenAt: Date()))
        })
        let state = MojiLearnPageState(
            introducedIDs: batch.characterIDs,
            freshIDs: [],
            lessonsCompleted: 1,
            lastLessonAt: Date()
        )
        guard let lesson = MojiLearnPlanner.shared.makeLesson(
            page: page,
            progress: progress,
            state: state,
            now: Date(),
            batchIndex: batch.index,
            using: &generator
        ),
            let index = lesson.items.firstIndex(where: { $0.step.kind == .write }) else {
            return nil
        }
        return LessonExerciseModel.make(
            lessonID: lesson.id,
            page: page,
            position: index,
            item: lesson.items[index],
            catalog: .shared
        )
    }

    static func batchStates(_ page: MojiPage) -> [MojiLearnBatchState] {
        let statuses: [MojiLearnBatchStatus] = [.learned, .current, .review, .new, .new]
        return zip(MojiLearnPlanner.shared.batches(page), statuses).map { batch, status in
            MojiLearnBatchState(batch: batch, status: status, mastery: status == .learned ? 0.7 : 0)
        }
    }

    static func lessonSummary(_ page: MojiPage) -> LessonSummaryModel {
        let pool = MojiAlphabetCatalog.shared.pool(page)
        let batches = MojiLearnPlanner.shared.batches(page)
        return LessonSummaryModel(
            page: page,
            isReview: false,
            batchNumber: 3,
            batchCount: batches.count,
            answered: 14,
            correct: 12,
            hardDone: 2,
            characters: pool.prefix(8).enumerated().map { index, character in
                LessonSummaryCharacter(character: character, strength: index % 6, isNew: index < 5)
            },
            next: .batch(
                number: 4,
                characters: batches.dropFirst(3).first?.characterIDs.compactMap { MojiAlphabetCatalog.shared.character($0) } ?? []
            ),
            streakDay: 6
        )
    }
}

private struct LessonExercisePreview: View {
    let model: LessonExerciseModel?

    var body: some View {
        ZStack {
            AppBackground()
            if let model {
                VStack(spacing: 0) {
                    LessonTopBar(progress: 0.35, onClose: {})
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    LessonExerciseView(model: model)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                Text(verbatim: "This plan has no such exercise. Refresh the preview.")
                    .padding()
            }
        }
    }
}

private struct QuestionPreview: View {
    let page: MojiPage
    let reveal: Bool
    var mode: MojiAnswerMode = .standard

    var body: some View {
        ZStack {
            AppBackground()
            if let model = MojiPreviewData.question(page, mode: mode) {
                VStack(spacing: 0) {
                    PracticeTopBar(
                        answered: model.index,
                        total: model.total,
                        combo: model.combo,
                        onClose: {}
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    PracticeQuestionView(
                        model: model,
                        reveal: reveal
                            ? PracticeReveal(
                                chosenID: model.options.first { $0.id != model.correctOptionID }?.id,
                                isCorrect: false
                            )
                            : nil
                    )
                }
            }
        }
    }
}

#Preview("Learn") {
    ThemeRootBoundary {
        MainTabs()
    }
}

#Preview("Learn · kanji groups, all open") {
    ZStack {
        AppBackground()
        ScrollView {
            VStack(spacing: 10) {
                ForEach(MojiPreviewData.batchStates(.kanji(.describing))) { state in
                    LearnBatchRow(state: state)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }
}

#Preview("Question · kana") {
    QuestionPreview(page: .hiragana, reveal: false)
}

#Preview("Question · kanji, wrong answer") {
    QuestionPreview(page: .kanji(.people), reveal: true)
}

#Preview("Question · kanji, typed reading") {
    QuestionPreview(page: .kanji(.time), reveal: false, mode: MojiAnswerMode(input: .keyboard, side: .romaji))
}

#Preview("Question · typed kana") {
    QuestionPreview(page: .katakana, reveal: false, mode: MojiAnswerMode(input: .keyboard, side: .character))
}

#Preview("Session complete") {
    ZStack {
        AppBackground()
        PracticeSummaryView(summary: MojiPreviewData.summary(.kanji(.food)))
    }
}

#Preview("Lesson · new kanji") {
    LessonExercisePreview(model: MojiPreviewData.exercise(.kanji(.people), kind: .intro))
}

#Preview("Lesson · pick the answer") {
    LessonExercisePreview(model: MojiPreviewData.exercise(.hiragana, kind: .choice))
}

#Preview("Lesson · match the pairs") {
    LessonExercisePreview(model: MojiPreviewData.exercise(.hiragana, kind: .match))
}

#Preview("Lesson · listen and type") {
    LessonExercisePreview(model: MojiPreviewData.exercise(.hiragana, kind: .word))
}

#Preview("Lesson · write the group") {
    LessonExercisePreview(model: MojiPreviewData.writing(.kanji(.people)))
}

#Preview("Lesson · write the group, kana") {
    LessonExercisePreview(model: MojiPreviewData.writing(.hiragana))
}

#Preview("Lesson · read it, hard") {
    LessonExercisePreview(model: MojiPreviewData.exercise(.hiragana, kind: .read, hard: true))
}

#Preview("Lesson complete") {
    ZStack {
        AppBackground()
        LessonSummaryView(summary: MojiPreviewData.lessonSummary(.hiragana))
    }
}

#Preview("Lesson complete · kanji") {
    ZStack {
        AppBackground()
        LessonSummaryView(summary: MojiPreviewData.lessonSummary(.kanji(.feelings)))
    }
}
#endif
