import Foundation
import Observation

@MainActor
@Observable
final class AlphabetInteractionsStore {
    static let shared = AlphabetInteractionsStore()

    private var service: AlphabetServicesStore { .shared }
    private var practiceActions: PracticeActionsStore { .shared }
    private var searchInteractions: SearchInteractionsStore { .shared }
    private var catalog: MojiAlphabetCatalog { .shared }

    private init() {}

    func selectScript(_ script: MojiScript) {
        guard service.activeScript != script else { return }
        service.activeScript = script
        UserDefaults.standard.set(script.rawValue, forKey: AlphabetServicesStore.activeScriptKey)
        MojiHaptics.selection()
    }

    func selectTheme(_ theme: MojiKanjiTheme) {
        guard service.activeTheme != theme else { return }
        showTheme(theme)
        MojiHaptics.selection()
        searchInteractions.activePageDidChange(on: .practice)
    }

    func revealTheme(_ theme: MojiKanjiTheme) {
        guard service.activeTheme != theme else { return }
        showTheme(theme)
    }

    private func showTheme(_ theme: MojiKanjiTheme) {
        service.activeTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: AlphabetServicesStore.activeThemeKey)
    }

    func openCharacter(_ character: MojiCharacter) {
        service.detailCharacter = character
    }

    func closeCharacter() {
        service.detailCharacter = nil
    }

    func speak(_ character: MojiCharacter) {
        MojiSpeech.shared.speak(character)
    }

    func characterDetailDidAppear(_ character: MojiCharacter) {
        guard MojiPreferencesStore.shared.speaksCharacters else { return }
        MojiSpeech.shared.speak(character)
    }

    func openProfile() {
        MojiHaptics.selection()
        MainTabRouter.shared.select(.profile)
    }

    func setStrength(_ strength: Int, for character: MojiCharacter) {
        let level = min(MojiCharacterProgress.masteryLevel, max(0, strength))
        practiceActions.setStrengthAction(level, characterIDs: [character.id])
        MojiHaptics.selection()
    }

    func requestMarkKnown(_ page: MojiPage) {
        requestBulk(.known, title: page.title, ids: catalog.pool(page).map(\.id), isWholeScript: true)
    }

    func requestMarkKnown(_ section: MojiCharacterSection) {
        requestBulk(.known, title: service.title(of: section), ids: memberIDs(section), isWholeScript: false)
    }

    func requestReset(_ page: MojiPage) {
        requestBulk(.reset, title: page.title, ids: catalog.pool(page).map(\.id), isWholeScript: true)
    }

    func requestReset(_ section: MojiCharacterSection) {
        requestBulk(.reset, title: service.title(of: section), ids: memberIDs(section), isWholeScript: false)
    }

    func confirmBulkMark() {
        guard let mark = service.bulkMark else { return }
        service.bulkMark = nil
        let level = mark.kind == .known ? MojiCharacterProgress.masteryLevel : 0
        practiceActions.setStrengthAction(level, characterIDs: mark.characterIDs)
        if mark.kind == .known {
            MojiHaptics.success()
        } else {
            MojiHaptics.impact()
        }
    }

    func cancelBulkMark() {
        service.bulkMark = nil
    }

    private func requestBulk(
        _ kind: AlphabetBulkMark.Kind,
        title: String,
        ids: [String],
        isWholeScript: Bool
    ) {
        guard !ids.isEmpty else { return }
        MojiHaptics.selection()
        service.bulkMark = AlphabetBulkMark(
            kind: kind,
            title: title,
            characterIDs: ids,
            isWholeScript: isWholeScript
        )
    }

    private func memberIDs(_ section: MojiCharacterSection) -> [String] {
        catalog.members(ofSection: section.id).map(\.id)
    }
}
