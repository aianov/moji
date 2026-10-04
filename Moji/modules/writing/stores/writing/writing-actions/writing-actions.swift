import Foundation
import Observation

@MainActor
@Observable
final class WritingActionsStore {
    static let shared = WritingActionsStore()

    private init() {}

    func canWrite(_ character: MojiCharacter) -> Bool {
        MojiStrokeLibrary.shared?.canWrite(character.glyph) ?? false
    }

    func makeBlockAction(_ characters: [MojiCharacter]) -> MojiWritingBlock? {
        guard let library = MojiStrokeLibrary.shared else { return nil }
        var seen: Set<String> = []
        let cards = characters.compactMap { character -> MojiWritingCard? in
            guard seen.insert(character.id).inserted,
                  let figure = library.figure(for: character.glyph) else { return nil }
            return MojiWritingCard(id: character.id, figure: figure)
        }
        return MojiWritingBlock(cards: cards)
    }

    func speakAction(_ character: MojiCharacter) {
        MojiSpeech.shared.speak(character)
    }

    func stopSpeakingAction() {
        MojiSpeech.shared.stop()
    }
}
