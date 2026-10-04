import SwiftUI

struct LearnLaunchBar: View {
    let page: MojiPage
    let path: MojiLearnPath

    private var service: LearnServicesStore { .shared }
    private var interactions: LearnInteractionsStore { .shared }

    var body: some View {
        VStack(spacing: 10) {
            CharacterSearchField(surface: .learn, script: page.script)

            ProgressCapsuleButton(
                title: path.isComplete || path.current == nil
                    ? String(localized: "Review lesson")
                    : String(localized: "Start lesson"),
                systemImage: "play.fill",
                role: .primary,
                action: { interactions.startLesson(page) }
            )
            .disabled(!service.isLoaded)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}
