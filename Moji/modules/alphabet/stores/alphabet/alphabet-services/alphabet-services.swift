import Foundation
import Observation

struct AlphabetBulkMark: Identifiable, Equatable {
    enum Kind: Equatable {
        case known
        case reset
    }

    let kind: Kind
    let title: String
    let characterIDs: [String]
    let isWholeScript: Bool

    var id: String { "\(kind)#\(title)#\(characterIDs.count)" }
}

@MainActor
@Observable
final class AlphabetServicesStore {
    static let shared = AlphabetServicesStore()

    static let activeScriptKey = "moji.alphabet.active_script.v1"
    static let activeThemeKey = "moji.alphabet.kanji_theme.v1"

    var activeScript: MojiScript
    var activeTheme: MojiKanjiTheme
    var detailCharacter: MojiCharacter?
    var bulkMark: AlphabetBulkMark?

    private init() {
        let defaults = UserDefaults.standard
        activeScript = defaults
            .string(forKey: Self.activeScriptKey)
            .flatMap(MojiScript.init(storedValue:)) ?? .hiragana
        activeTheme = defaults
            .string(forKey: Self.activeThemeKey)
            .flatMap(MojiKanjiTheme.init(rawValue:)) ?? .people
    }

    var activePage: MojiPage {
        page(for: activeScript)
    }

    func page(for script: MojiScript) -> MojiPage {
        MojiPage(script: script, theme: activeTheme)
    }

    func sections(_ page: MojiPage) -> [MojiCharacterSection] {
        MojiAlphabetCatalog.shared.sections(page)
    }

    func title(of section: MojiCharacterSection) -> String {
        section.title ?? String(localized: "Basic characters")
    }
}
