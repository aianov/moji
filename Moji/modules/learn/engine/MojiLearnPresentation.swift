import Foundation
import Observation

@MainActor
@Observable
final class MojiLearnPresentation {
    static let shared = MojiLearnPresentation()

    private(set) var snapshot = MojiLearnRepositorySnapshot.empty

    private init() {}

    func publish(_ value: MojiLearnRepositorySnapshot) {
        guard value != snapshot else { return }
        snapshot = value
    }
}
