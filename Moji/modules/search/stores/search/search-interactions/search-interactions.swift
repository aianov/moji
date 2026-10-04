import Foundation
import Observation

@MainActor
@Observable
final class SearchInteractionsStore {
    static let shared = SearchInteractionsStore()

    private var service: SearchServicesStore { .shared }

    private init() {}

    func setQuery(_ query: String, on surface: CharacterSearchSurface) {
        var state = service.state(surface)
        guard state.query != query else { return }
        state.query = query
        refresh(&state, on: surface, restart: false)
        service.setState(state, on: surface)
        reveal(state.focus, on: surface)
    }

    func clear(on surface: CharacterSearchSurface) {
        guard !service.state(surface).query.isEmpty else { return }
        service.setState(CharacterSearchState(), on: surface)
    }

    func nextMatch(on surface: CharacterSearchSurface) {
        var state = service.state(surface)
        guard state.script != nil, !state.ordered.isEmpty else { return }
        state.position = (state.position + 1) % state.ordered.count
        state.focus = service.makeFocus(characterID: state.ordered[state.position])
        service.setState(state, on: surface)
        reveal(state.focus, on: surface)
        MojiHaptics.selection()
    }

    func beginEditing(on surface: CharacterSearchSurface) {
        guard service.editingSurface != surface else { return }
        service.editingSurface = surface
    }

    func endEditing(on surface: CharacterSearchSurface) {
        guard service.editingSurface == surface else { return }
        service.editingSurface = nil
    }

    func activeScriptDidChange(on surface: CharacterSearchSurface) {
        var state = service.state(surface)
        guard !state.query.isEmpty else { return }
        refresh(&state, on: surface, restart: true)
        service.setState(state, on: surface)
        reveal(state.focus, on: surface)
    }

    func activePageDidChange(on surface: CharacterSearchSurface) {
        var state = service.state(surface)
        guard !state.query.isEmpty else { return }
        let script = service.activeScript(surface)
        let page = service.activePage(surface)
        let ordered = service.matches(of: state.query, in: script, on: surface)
        state.script = script
        state.ordered = ordered
        state.found = Set(ordered)
        if let first = ordered.first, service.page(of: first) == page {
            state.position = 0
            state.focus = service.makeFocus(characterID: first)
        } else {
            state.position = -1
            state.focus = nil
        }
        service.setState(state, on: surface)
    }

    private func refresh(
        _ state: inout CharacterSearchState,
        on surface: CharacterSearchSurface,
        restart: Bool
    ) {
        let script = service.activeScript(surface)
        let ordered = service.matches(of: state.query, in: script, on: surface)
        guard restart || state.script != script || state.ordered != ordered else { return }
        state.script = script
        state.ordered = ordered
        state.found = Set(ordered)
        state.position = 0
        state.focus = ordered.first.flatMap { service.makeFocus(characterID: $0) }
    }

    private func reveal(_ focus: CharacterSearchFocus?, on surface: CharacterSearchSurface) {
        guard let theme = focus?.page.theme else { return }
        switch surface {
        case .learn: LearnInteractionsStore.shared.revealTheme(theme)
        case .practice: AlphabetInteractionsStore.shared.revealTheme(theme)
        }
    }
}
