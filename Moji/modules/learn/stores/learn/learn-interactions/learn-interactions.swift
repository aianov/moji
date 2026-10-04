import Foundation
import Observation

@MainActor
@Observable
final class LearnInteractionsStore {
    static let shared = LearnInteractionsStore()

    private var actions: LearnActionsStore { .shared }
    private var service: LearnServicesStore { .shared }
    private var preferences: MojiPreferencesStore { .shared }
    private var searchInteractions: SearchInteractionsStore { .shared }
    private var catalog: MojiAlphabetCatalog { .shared }

    private init() {}

    func selectScript(_ script: MojiScript) {
        guard service.activeScript != script else { return }
        service.activeScript = script
        UserDefaults.standard.set(script.rawValue, forKey: LearnServicesStore.activeScriptKey)
        MojiHaptics.selection()
    }

    func selectTheme(_ theme: MojiKanjiTheme) {
        guard service.activeTheme != theme else { return }
        showTheme(theme)
        MojiHaptics.selection()
        searchInteractions.activePageDidChange(on: .learn)
    }

    func revealTheme(_ theme: MojiKanjiTheme) {
        guard service.activeTheme != theme else { return }
        showTheme(theme)
    }

    private func showTheme(_ theme: MojiKanjiTheme) {
        service.activeTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: LearnServicesStore.activeThemeKey)
    }

    func openCharacter(_ character: MojiCharacter) {
        MojiHaptics.selection()
        service.detailCharacter = character
    }

    func closeCharacter() {
        service.detailCharacter = nil
    }

    func openProfile() {
        MojiHaptics.selection()
        MainTabRouter.shared.select(.profile)
    }

    func requestMarkPageKnown(_ page: MojiPage) {
        let ids = catalog.pool(page).map(\.id)
        guard !ids.isEmpty else { return }
        MojiHaptics.selection()
        service.bulkMark = LearnBulkMark(
            title: page.title,
            characterIDs: ids,
            isWholeScript: true
        )
    }

    func requestMarkSectionKnown(_ section: MojiCharacterSection) {
        let ids = catalog.members(ofSection: section.id).map(\.id)
        guard !ids.isEmpty else { return }
        MojiHaptics.selection()
        service.bulkMark = LearnBulkMark(
            title: Self.title(of: section),
            characterIDs: ids,
            isWholeScript: false
        )
    }

    func confirmBulkMark() {
        guard let mark = service.bulkMark else { return }
        service.bulkMark = nil
        actions.setStrengthAction(MojiCharacterProgress.masteryLevel, characterIDs: mark.characterIDs)
        MojiHaptics.success()
    }

    func cancelBulkMark() {
        service.bulkMark = nil
    }

    static func title(of section: MojiCharacterSection) -> String {
        section.title ?? String(localized: "Basic characters")
    }

    func startLesson() {
        startLesson(service.activePage)
    }

    func startLesson(_ page: MojiPage, batchIndex: Int? = nil) {
        guard service.presented == nil else { return }
        service.resetLessonState()
        let token = UUID()
        service.presented = LearnPresentedLesson(page: page, token: token)
        MojiHaptics.impact()

        Task {
            var waited = 0
            while !MojiPracticePresentation.shared.snapshot.isLoaded, waited < 60 {
                try? await Task.sleep(for: .milliseconds(50))
                waited += 1
            }
            let snapshot = MojiPracticePresentation.shared.snapshot
            let lesson = snapshot.isLoaded
                ? await actions.makeLessonAction(page, batchIndex: batchIndex, progress: snapshot.progress)
                : nil

            guard service.presented?.token == token, service.stage == .loading else { return }
            guard let lesson, !lesson.items.isEmpty else {
                service.stage = .unavailable
                return
            }
            service.lesson = lesson
            service.queue = lesson.items
            service.queueCount = lesson.items.count
            service.baseline = snapshot.progress
            service.startedAt = Date()
            showCurrent()
        }
    }

    func continueLesson() {
        guard let model = service.currentExercise,
              model.kind == .intro || service.feedback != nil else { return }
        service.position += 1
        service.finishedCount += 1
        showCurrent()
    }

    func choose(_ optionID: String) {
        guard let model = service.currentExercise, service.feedback == nil,
              service.chosenOptionID != optionID else { return }
        switch model.content {
        case .choice, .listen:
            MojiHaptics.selection()
            service.chosenOptionID = optionID
        default:
            return
        }
    }

    func chooseWord(_ index: Int) {
        guard let model = service.currentExercise,
              service.feedback == nil,
              service.chosenWordIndex != index,
              case .word(_, let options?) = model.content,
              options.indices.contains(index) else { return }
        MojiHaptics.selection()
        service.chosenWordIndex = index
    }

    func check() {
        guard let model = service.currentExercise, service.feedback == nil else { return }
        switch model.content {
        case .choice(let prompt, _, _):
            settleChoice(model, answer: prompt)
        case .listen(let target, _):
            settleChoice(model, answer: target)
        case .word(let target, let options?):
            settleWord(model, target: target, options: options)
        case .word(_, .none), .read:
            submitTyped()
        case .intro, .match:
            break
        }
    }

    private func settleChoice(_ model: LessonExerciseModel, answer: MojiCharacter) {
        guard let optionID = service.chosenOptionID else { return }
        let isCorrect = optionID == answer.id
        settle(
            model,
            results: [(answer.id, isCorrect)],
            feedback: isCorrect ? rightFeedback(model) : wrongFeedback(answerLine([answer]))
        )
    }

    private func settleWord(_ model: LessonExerciseModel, target: [MojiCharacter], options: [[MojiCharacter]]) {
        guard let index = service.chosenWordIndex, options.indices.contains(index) else { return }
        let chosen = options[index]
        let isCorrect = chosen.map(\.id) == target.map(\.id)
        let tested = target.indices.filter { position in
            options.contains { option in
                option.indices.contains(position) && option[position].id != target[position].id
            }
        }
        var results: [(String, Bool)]
        if isCorrect {
            results = tested.map { (target[$0].id, true) }
        } else {
            results = tested.compactMap { position in
                chosen.indices.contains(position) && chosen[position].id != target[position].id
                    ? (target[position].id, false)
                    : nil
            }
        }
        if results.isEmpty, let first = target.first {
            results = [(first.id, isCorrect)]
        }
        settle(
            model,
            results: results,
            feedback: isCorrect ? rightFeedback(model) : wrongFeedback(answerLine(target))
        )
    }

    func setTypedText(_ text: String) {
        guard service.feedback == nil else { return }
        service.typedText = text
    }

    func useHint() {
        guard let model = service.currentExercise, service.feedback == nil else { return }
        let characters: [MojiCharacter]
        switch model.content {
        case .word(let target, .none), .read(let target):
            characters = target
        default:
            return
        }
        service.typedText = characters.map { $0.romaji.filter { $0 != "(" && $0 != ")" } }.joined()
    }

    func submitTyped() {
        guard let model = service.currentExercise, service.feedback == nil else { return }
        let characters: [MojiCharacter]
        let allowsOtherReadings: Bool
        switch model.content {
        case .word(let target, .none):
            characters = target
            allowsOtherReadings = false
        case .read(let target):
            characters = target
            allowsOtherReadings = true
        default:
            return
        }
        let typed = service.typedText
        guard !MojiLearnGrading.normalizedRomaji(typed).isEmpty else { return }

        let flags = MojiLearnGrading.gradeTyped(
            typed,
            characters: characters,
            allowsOtherReadings: allowsOtherReadings
        )
        let isCorrect = flags.allSatisfy { $0 }
        settle(
            model,
            results: zip(characters, flags).map { ($0.id, $1) },
            feedback: isCorrect ? rightFeedback(model) : wrongFeedback(answerLine(characters))
        )
    }

    func tapMatchLeft(_ id: String) {
        guard service.feedback == nil, !service.matchedIDs.contains(id) else { return }
        if let right = service.matchSelectedRight {
            attemptPair(left: id, right: right)
            return
        }
        service.matchSelectedLeft = service.matchSelectedLeft == id ? nil : id
        MojiHaptics.selection()
    }

    func tapMatchRight(_ id: String) {
        guard service.feedback == nil, !service.matchedIDs.contains(id) else { return }
        if let left = service.matchSelectedLeft {
            attemptPair(left: left, right: id)
            return
        }
        service.matchSelectedRight = service.matchSelectedRight == id ? nil : id
        MojiHaptics.selection()
    }

    func openWriting(_ batch: MojiLearnBatch) {
        let characters = WritingPracticeRequest.available(batch.characterIDs.compactMap { catalog.character($0) })
        guard !characters.isEmpty else { return }
        MojiHaptics.impact()
        service.writingPractice = LearnWritingPractice(
            batch: batch,
            request: WritingPracticeRequest(
                title: batch.page.isKanji ? String(localized: "Write these kanji") : String(localized: "Write these characters"),
                characters: characters
            )
        )
    }

    func closeWriting() {
        service.writingPractice = nil
    }

    func finishPracticeWriting(_ practice: LearnWritingPractice, cards: [MojiWritingCard]) {
        guard !cards.isEmpty else { return }
        PracticeActionsStore.shared.markWrittenAction(cards.map(\.id))
    }

    func replay() {
        guard let model = service.currentExercise else { return }
        let answered = service.feedback != nil
        guard !model.isHard || answered else { return }

        switch model.content {
        case .intro(let character), .listen(let character, _):
            MojiSpeech.shared.speak(character)
        case .choice(let prompt, _, _):
            guard answered else { return }
            MojiSpeech.shared.speak(prompt)
        case .word(let characters, _):
            MojiSpeech.shared.speak(sequence: characters)
        case .read(let characters):
            guard answered else { return }
            MojiSpeech.shared.speak(sequence: characters)
        case .match:
            break
        }
    }

    func speak(_ character: MojiCharacter) {
        MojiSpeech.shared.speak(character)
    }

    func close() {
        switch service.stage {
        case .exercise:
            MojiHaptics.selection()
            service.isExitAlertPresented = true
        case .loading, .writingNotice, .finished, .unavailable:
            dismiss()
        }
    }

    func showSummary() {
        guard case .writingNotice(let summary) = service.stage else { return }
        service.stage = .finished(summary)
    }

    func keepLearning() {
        service.isExitAlertPresented = false
    }

    func leaveLesson() {
        service.isExitAlertPresented = false
        service.exitTask = Task {
            await Task.yield()
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    func finish() {
        dismiss()
    }

    func didDismiss() {
        WritingInteractionsStore.shared.stop()
        MojiSpeech.shared.stop()
        service.resetLessonState()
    }

    private func showCurrent() {
        guard let lesson = service.lesson else {
            service.stage = .unavailable
            return
        }
        while service.position < service.queue.count {
            if let model = LessonExerciseModel.make(
                lessonID: lesson.id,
                page: lesson.page,
                position: service.position,
                item: service.queue[service.position],
                catalog: catalog
            ) {
                service.resetExerciseState()
                service.stage = .exercise(model)
                exerciseDidAppear(model)
                return
            }
            service.position += 1
            service.finishedCount += 1
        }
        finishLesson()
    }

    private func exerciseDidAppear(_ model: LessonExerciseModel) {
        guard preferences.speaksCharacters, !model.isHard else { return }
        switch model.content {
        case .intro(let character), .listen(let character, _):
            MojiSpeech.shared.speak(character)
        case .word(let characters, _):
            MojiSpeech.shared.speak(sequence: characters)
        case .choice, .match, .read:
            break
        }
    }

    private func settle(
        _ model: LessonExerciseModel,
        results: [(String, Bool)],
        feedback: LessonFeedback
    ) {
        guard service.feedback == nil, service.currentExercise?.id == model.id else { return }

        for (id, isCorrect) in results {
            record(id, correct: isCorrect, steps: isCorrect && model.isHard ? 2 : 1)
        }
        service.gradedCount += results.count
        service.correctCount += results.filter { $0.1 }.count

        let isCorrect = results.allSatisfy { $0.1 }
        if isCorrect, model.isHard {
            service.hardDone += 1
        }
        if !isCorrect {
            requeue(model)
        }

        service.feedback = feedback
        if isCorrect {
            MojiHaptics.success()
        } else {
            MojiHaptics.error()
        }
        if preferences.speaksCharacters {
            speakAnswer(of: model)
        }
    }

    private func record(_ id: String, correct: Bool, steps: Int) {
        actions.recordAnswerAction(characterID: id, correct: correct, steps: steps)
        service.answers.append(MojiLessonAnswer(characterID: id, isCorrect: correct, steps: steps))
    }

    private func requeue(_ model: LessonExerciseModel) {
        let key = "\(model.kind.rawValue):\(model.item.step.characterIDs.joined(separator: ","))"
        guard service.retryCount < MojiLearnPlanner.maxRetriesPerLesson,
              service.retriesByKey[key, default: 0] < MojiLearnPlanner.maxRetriesPerItem else { return }
        service.retriesByKey[key, default: 0] += 1
        service.retryCount += 1
        service.queue.append(actions.retryItem(model.item))
        service.queueCount = service.queue.count
    }

    private func speakAnswer(of model: LessonExerciseModel) {
        switch model.content {
        case .choice(let character, _, _), .listen(let character, _):
            MojiSpeech.shared.speak(character)
        case .word(let characters, _), .read(let characters):
            MojiSpeech.shared.speak(sequence: characters)
        case .intro, .match:
            break
        }
    }

    private func attemptPair(left: String, right: String) {
        guard let model = service.currentExercise,
              case .match(let pairs, _) = model.content else { return }
        service.matchSelectedLeft = nil
        service.matchSelectedRight = nil

        guard left == right else {
            service.matchMissedIDs.insert(left)
            service.matchMissedIDs.insert(right)
            service.matchShake = LessonMatchShake(
                ids: [left, right],
                token: (service.matchShake?.token ?? 0) + 1
            )
            MojiHaptics.error()
            return
        }

        service.matchedIDs.insert(left)
        MojiHaptics.selection()
        if preferences.speaksCharacters, let character = catalog.character(left) {
            MojiSpeech.shared.speak(character)
        }
        guard service.matchedIDs.count == pairs.count else { return }

        let misses = service.matchMissedIDs
        settle(
            model,
            results: pairs.map { ($0.id, !misses.contains($0.id)) },
            feedback: misses.isEmpty
                ? LessonFeedback(isCorrect: true, title: String(localized: "All pairs matched"), detail: nil)
                : LessonFeedback(
                    isCorrect: false,
                    title: String(localized: "Matched, with mix-ups"),
                    detail: String(localized: "The pairs you mixed up come back at the end.")
                )
        )
    }

    private func finishLesson() {
        guard let lesson = service.lesson else {
            dismiss()
            return
        }
        let summary = makeSummary(lesson)
        service.stage = needsWriting(lesson) ? .writingNotice(summary) : .finished(summary)
        actions.completeLessonAction(lesson)
        actions.recordLessonActivityAction(
            page: lesson.page,
            total: service.gradedCount,
            correct: service.correctCount,
            startedAt: service.startedAt
        )
        MojiHaptics.success()
    }

    private func needsWriting(_ lesson: MojiLesson) -> Bool {
        guard let index = lesson.batchIndex,
              let batch = MojiLearnPlanner.shared.batches(lesson.page).first(where: { $0.index == index }) else {
            return false
        }
        let after = MojiLearnPlanner.applying(service.answers, to: service.baseline, at: Date())
        let writable = Set(WritingPracticeRequest.available(batch.characterIDs.compactMap { catalog.character($0) }).map(\.id))
        guard !writable.isEmpty,
              batch.characterIDs.allSatisfy({ after[$0]?.isRecognized ?? false }) else { return false }
        return writable.contains { !(after[$0]?.isWritten ?? false) }
    }

    private func makeSummary(_ lesson: MojiLesson) -> LessonSummaryModel {
        let planner = MojiLearnPlanner.shared
        let now = Date()
        let after = MojiLearnPlanner.applying(service.answers, to: service.baseline, at: now)
        let stateAfter = service.state(for: lesson.page).completing(lesson, at: now)
        let pathAfter = planner.path(page: lesson.page, progress: after, state: stateAfter)
        let newIDs = Set(lesson.newCharacterIDs)
        let activity = service.activity
        let streakDay = activity.isTodayDone ? nil : activity.currentStreak + 1

        return LessonSummaryModel(
            page: lesson.page,
            isReview: lesson.isReview,
            batchNumber: lesson.batchIndex.map { $0 + 1 },
            batchCount: planner.batches(lesson.page).count,
            answered: service.gradedCount,
            correct: service.correctCount,
            hardDone: service.hardDone,
            characters: lesson.coveredCharacterIDs.compactMap { id in
                catalog.character(id).map { character in
                    LessonSummaryCharacter(
                        character: character,
                        strength: after[id]?.strength ?? 0,
                        isNew: newIDs.contains(id),
                        isWritten: after[id]?.isWritten ?? false
                    )
                }
            },
            next: nextStep(after: lesson, on: pathAfter),
            streakDay: streakDay
        )
    }

    private func nextStep(after lesson: MojiLesson, on path: MojiLearnPath) -> LessonSummaryNext {
        guard let current = path.current else { return .allLearned }
        guard current.batch.index != lesson.batchIndex else { return .sameBatch }
        return .batch(
            number: current.batch.index + 1,
            characters: current.batch.characterIDs.compactMap { catalog.character($0) }
        )
    }

    private func dismiss() {
        service.isExitAlertPresented = false
        service.presented = nil
    }

    private func rightFeedback(_ model: LessonExerciseModel) -> LessonFeedback {
        LessonFeedback(
            isCorrect: true,
            title: String(localized: "Correct"),
            detail: model.isHard ? String(localized: "Hard exercise: counts twice") : nil
        )
    }

    private func wrongFeedback(_ answer: String) -> LessonFeedback {
        LessonFeedback(
            isCorrect: false,
            title: String(localized: "Not quite"),
            detail: answer
        )
    }

    private func answerLine(_ characters: [MojiCharacter]) -> String {
        let glyphs = characters.map(\.glyph).joined()
        if characters.count == 1, let character = characters.first, let meaning = character.meaning {
            return String(localized: "Answer: \(glyphs) · \(meaning) · \(character.readingLine)")
        }
        let romaji = characters.map(\.romaji).joined()
        return String(localized: "Answer: \(glyphs) · \(romaji)")
    }
}
