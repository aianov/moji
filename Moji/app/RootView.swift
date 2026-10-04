import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    private var practice: PracticeServicesStore { .shared }
    private var practiceInteractions: PracticeInteractionsStore { .shared }
    private var learn: LearnServicesStore { .shared }
    private var learnInteractions: LearnInteractionsStore { .shared }
    private var words: WordsServicesStore { .shared }
    private var wordsInteractions: WordsInteractionsStore { .shared }

    var body: some View {
        let presentedPractice = Binding(
            get: { practice.presented },
            set: { if $0 == nil { practiceInteractions.finish() } }
        )
        let presentedLesson = Binding(
            get: { learn.presented },
            set: { if $0 == nil { learnInteractions.finish() } }
        )
        let presentedWords = Binding(
            get: { words.presented },
            set: { if $0 == nil { wordsInteractions.finishStudy() } }
        )

        MainTabs()
            .fullScreenCover(
                item: presentedPractice,
                onDismiss: { practiceInteractions.didDismiss() }
            ) { session in
                PracticeSessionPage(page: session.page)
                    .themedPresentation()
            }
            .fullScreenCover(
                item: presentedLesson,
                onDismiss: { learnInteractions.didDismiss() }
            ) { _ in
                LessonPage()
                    .themedPresentation()
            }
            .fullScreenCover(
                item: presentedWords,
                onDismiss: { wordsInteractions.studyDidDismiss() }
            ) { _ in
                WordsStudyPage()
                    .themedPresentation()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    MojiEngineRuntime.shared.clockDidMove()
                case .background:
                    MojiEngineRuntime.shared.appDidLeaveForeground()
                default:
                    break
                }
            }
    }
}
