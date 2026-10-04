import Foundation
import Observation

@MainActor
@Observable
final class MojiWordPresentation {
    static let shared = MojiWordPresentation()

    private(set) var snapshot = MojiWordRepositorySnapshot.empty
    private(set) var mine = MojiWordRepositorySnapshot.empty

    private init() {}

    func snapshot(for deck: MojiWordDeck) -> MojiWordRepositorySnapshot {
        switch deck {
        case .frequent: snapshot
        case .mine: mine
        }
    }

    func publish(_ value: MojiWordRepositorySnapshot, deck: MojiWordDeck = .frequent) {
        switch deck {
        case .frequent:
            guard value != snapshot else { return }
            snapshot = value
        case .mine:
            guard value != mine else { return }
            mine = value
        }
    }
}
