import Foundation
import Observation

@MainActor
@Observable
final class MojiNotePresentation {
    static let shared = MojiNotePresentation()

    private(set) var snapshot = MojiNoteRepositorySnapshot.empty

    private init() {}

    func publish(_ value: MojiNoteRepositorySnapshot) {
        guard value != snapshot else { return }
        snapshot = value
    }
}
