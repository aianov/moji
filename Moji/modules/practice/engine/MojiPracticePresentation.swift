import Foundation
import Observation

@MainActor
@Observable
final class MojiPracticePresentation {
    static let shared = MojiPracticePresentation()

    private(set) var snapshot = MojiPracticeRepositorySnapshot.empty

    private init() {}

    func publish(_ value: MojiPracticeRepositorySnapshot) {
        guard value != snapshot else { return }
        snapshot = value
    }
}
