#if DEBUG
import SwiftUI

private struct WritingBlockPreview: View {
    let characterIDs: [String]

    private var service: WritingServicesStore { .shared }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()
            WritingBlockView()

            if service.isFinished {
                ProgressCapsuleButton(
                    title: String(localized: "Continue"),
                    role: .primary,
                    action: start
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .onAppear(perform: start)
        .onDisappear { WritingInteractionsStore.shared.stop() }
    }

    private func start() {
        let characters = characterIDs.compactMap { MojiAlphabetCatalog.shared.character($0) }
        WritingInteractionsStore.shared.start(characters)
    }
}

#Preview("Writing · kanji") {
    WritingBlockPreview(characterIDs: ["j-日", "j-水", "j-火"])
}

#Preview("Writing · kana") {
    WritingBlockPreview(characterIDs: ["h-a", "h-nu", "h-kya"])
}

#Preview("Writing · katakana row") {
    WritingBlockPreview(characterIDs: ["k-kka", "k-aa"])
}
#endif
