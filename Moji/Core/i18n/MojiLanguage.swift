import Foundation

enum MojiLanguage: String, CaseIterable, Sendable {
    case en
    case ru

    static let current: MojiLanguage = {
        let preferred = Bundle.main.preferredLocalizations.first ?? "en"
        return preferred.hasPrefix("ru") ? .ru : .en
    }()
}
