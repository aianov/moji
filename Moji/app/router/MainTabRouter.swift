import Observation

enum MainTab: Hashable {
    case learn
    case practice
    case words
    case notes
    case profile
}

@MainActor
@Observable
final class MainTabRouter {
    static let shared = MainTabRouter()

    var currentTab: MainTab = .learn

    private init() {}

    func select(_ tab: MainTab) {
        guard currentTab != tab else { return }
        currentTab = tab
    }
}
