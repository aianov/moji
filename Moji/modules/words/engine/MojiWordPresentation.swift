import Foundation
import Observation

@MainActor
@Observable
final class MojiWordPresentation {
    static let shared = MojiWordPresentation()

    private(set) var snapshot = MojiWordRepositorySnapshot.empty

    private init() {}

    func publish(_ value: MojiWordRepositorySnapshot) {
        guard value != snapshot else { return }
        snapshot = value
    }
}
