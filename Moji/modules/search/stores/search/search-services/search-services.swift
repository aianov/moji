import Foundation
import Observation

@MainActor
@Observable
final class SearchServicesStore {
    static let shared = SearchServicesStore()

    var learn = CharacterSearchState()
    var practice = CharacterSearchState()
    var editingSurface: CharacterSearchSurface?

    @ObservationIgnored private var indexes: [MojiScript: MojiCharacterSearch] = [:]
    @ObservationIgnored private var focusCount = 0

    private init() {}

    func state(_ surface: CharacterSearchSurface) -> CharacterSearchState {
        switch surface {
        case .learn: learn
        case .practice: practice
        }
    }

    func setState(_ state: CharacterSearchState, on surface: CharacterSearchSurface) {
        switch surface {
        case .learn:
            if learn != state {
                learn = state
            }
        case .practice:
            if practice != state {
                practice = state
            }
        }
    }

    func isEditing(_ surface: CharacterSearchSurface) -> Bool {
        editingSurface == surface
    }

    func activeScript(_ surface: CharacterSearchSurface) -> MojiScript {
        switch surface {
        case .learn: LearnServicesStore.shared.activeScript
        case .practice: AlphabetServicesStore.shared.activeScript
        }
    }

    func activePage(_ surface: CharacterSearchSurface) -> MojiPage {
        switch surface {
        case .learn: LearnServicesStore.shared.activePage
        case .practice: AlphabetServicesStore.shared.activePage
        }
    }

    func matches(of query: String, in script: MojiScript, on surface: CharacterSearchSurface) -> [String] {
        let found = Set(index(for: script).matches(query))
        guard !found.isEmpty else { return [] }
        return searchOrder(script, on: surface).filter(found.contains)
    }

    func page(of characterID: String) -> MojiPage? {
        MojiAlphabetCatalog.shared.character(characterID)?.page
    }

    func makeFocus(characterID: String) -> CharacterSearchFocus? {
        guard let page = page(of: characterID) else { return nil }
        focusCount += 1
        return CharacterSearchFocus(page: page, characterID: characterID, token: focusCount)
    }

    private func searchOrder(_ script: MojiScript, on surface: CharacterSearchSurface) -> [String] {
        MojiAlphabetCatalog.shared
            .searchPages(script, from: activePage(surface))
            .flatMap { pageOrder(of: $0, on: surface) }
    }

    private func pageOrder(of page: MojiPage, on surface: CharacterSearchSurface) -> [String] {
        switch surface {
        case .learn: LearnServicesStore.shared.searchOrder(page)
        case .practice: AlphabetServicesStore.shared.searchOrder(page)
        }
    }

    private func index(for script: MojiScript) -> MojiCharacterSearch {
        if let index = indexes[script] {
            return index
        }
        let index = MojiCharacterSearch(characters: MojiAlphabetCatalog.shared.characters(script))
        indexes[script] = index
        return index
    }
}
