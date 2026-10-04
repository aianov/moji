import SwiftUI

struct LessonWriteView: View {
    let model: LessonExerciseModel

    private var interactions: LearnInteractionsStore { .shared }

    var body: some View {
        WritingBlockView(showsSummaryTitle: false)
            .onAppear { interactions.beginWriting(model) }
    }
}
