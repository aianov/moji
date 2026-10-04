import Foundation
import Observation

@MainActor
@Observable
final class LearnServicesStore {
    static let shared = LearnServicesStore()

    static let activeScriptKey = "moji.learn.active_script.v1"
    static let activeThemeKey = "moji.learn.kanji_theme.v1"

    var activeScript: MojiScript
    var activeTheme: MojiKanjiTheme
    var detailCharacter: MojiCharacter?
    var bulkMark: LearnBulkMark?

    var presented: LearnPresentedLesson?
    var stage: LearnStage = .loading
    var feedback: LessonFeedback?
    var isExitAlertPresented = false
    var finishedCount = 0
    var queueCount = 0

    var chosenOptionID: String?
    var chosenWordIndex: Int?
    var typedText = ""
    var matchSelectedLeft: String?
    var matchSelectedRight: String?
    var matchedIDs: Set<String> = []
    var matchMissedIDs: Set<String> = []
    var matchShake: LessonMatchShake?

    @ObservationIgnored var lesson: MojiLesson?
    @ObservationIgnored var queue: [MojiLessonItem] = []
    @ObservationIgnored var position = 0
    @ObservationIgnored var answers: [MojiLessonAnswer] = []
    @ObservationIgnored var retriesByKey: [String: Int] = [:]
    @ObservationIgnored var retryCount = 0
    @ObservationIgnored var hardDone = 0
    @ObservationIgnored var gradedCount = 0
    @ObservationIgnored var correctCount = 0
    @ObservationIgnored var baseline: [String: MojiCharacterProgress] = [:]
    @ObservationIgnored var startedAt = Date()
    @ObservationIgnored var writingExerciseID: String?
    @ObservationIgnored var exitTask: Task<Void, Never>?

    private init() {
        let defaults = UserDefaults.standard
        activeScript = defaults
            .string(forKey: Self.activeScriptKey)
            .flatMap(MojiScript.init(storedValue:)) ?? .hiragana
        activeTheme = defaults
            .string(forKey: Self.activeThemeKey)
            .flatMap(MojiKanjiTheme.init(rawValue:)) ?? .people
    }

    var activePage: MojiPage {
        page(for: activeScript)
    }

    func page(for script: MojiScript) -> MojiPage {
        MojiPage(script: script, theme: activeTheme)
    }

    var practiceSnapshot: MojiPracticeRepositorySnapshot {
        MojiPracticePresentation.shared.snapshot
    }

    var learnSnapshot: MojiLearnRepositorySnapshot {
        MojiLearnPresentation.shared.snapshot
    }

    var isLoaded: Bool {
        practiceSnapshot.isLoaded && learnSnapshot.isLoaded
    }

    var activity: MojiActivitySummary {
        practiceSnapshot.activity
    }

    var planner: MojiLearnPlanner {
        .shared
    }

    func state(for page: MojiPage) -> MojiLearnPageState {
        learnSnapshot.state.state(for: page)
    }

    func path(for page: MojiPage) -> MojiLearnPath {
        planner.path(
            page: page,
            progress: practiceSnapshot.progress,
            state: state(for: page)
        )
    }

    func pathSections(_ path: MojiLearnPath) -> [LearnPathSection] {
        var titles: [String: String] = [:]
        for section in sections(path.page) {
            if let title = section.title {
                titles[section.id] = title
            }
        }
        var result: [LearnPathSection] = []
        for state in path.batches {
            if let last = result.last, last.id == state.batch.sectionID {
                result[result.count - 1].batches.append(state)
            } else {
                result.append(
                    LearnPathSection(
                        id: state.batch.sectionID,
                        title: titles[state.batch.sectionID],
                        batches: [state]
                    )
                )
            }
        }
        return result
    }

    func strength(of characterID: String) -> Int {
        practiceSnapshot.progress[characterID]?.strength ?? 0
    }

    func character(_ id: String) -> MojiCharacter? {
        MojiAlphabetCatalog.shared.character(id)
    }

    func sections(_ page: MojiPage) -> [MojiCharacterSection] {
        MojiAlphabetCatalog.shared.sections(page)
    }

    var currentExercise: LessonExerciseModel? {
        guard case .exercise(let model) = stage else { return nil }
        return model
    }

    var lessonProgress: Double {
        guard queueCount > 0 else { return 0 }
        let done = finishedCount + (feedback == nil ? 0 : 1)
        return min(1, Double(done) / Double(queueCount))
    }

    func resetExerciseState() {
        feedback = nil
        chosenOptionID = nil
        chosenWordIndex = nil
        typedText = ""
        matchSelectedLeft = nil
        matchSelectedRight = nil
        matchedIDs = []
        matchMissedIDs = []
        matchShake = nil
        writingExerciseID = nil
    }

    func resetLessonState() {
        resetExerciseState()
        stage = .loading
        isExitAlertPresented = false
        finishedCount = 0
        queueCount = 0
        lesson = nil
        queue = []
        position = 0
        answers = []
        retriesByKey = [:]
        retryCount = 0
        hardDone = 0
        gradedCount = 0
        correctCount = 0
        baseline = [:]
        exitTask?.cancel()
        exitTask = nil
    }
}
