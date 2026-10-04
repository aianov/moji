import Foundation

actor MojiWordDomain {
    nonisolated let repository: MojiWordRepository
    nonisolated let mine: MojiWordRepository

    private var isActive = false

    init(store: MojiDiskStore) {
        repository = MojiWordRepository(
            resources: MojiWordResourceRepository(store: store)
        )
        mine = MojiWordRepository(
            resources: MojiWordResourceRepository(store: store, deck: .mine)
        )
    }

    nonisolated func repository(for deck: MojiWordDeck) -> MojiWordRepository {
        switch deck {
        case .frequent: repository
        case .mine: mine
        }
    }

    func activate() async {
        guard !isActive else { return }
        isActive = true

        await MainActor.run {
            MojiWordDomainRegistry.shared.install(self)
        }
        for deck in MojiWordDeck.allCases {
            await repository(for: deck).setPublisher { snapshot in
                await MainActor.run {
                    MojiWordPresentation.shared.publish(snapshot, deck: deck)
                }
            }
        }
        await withTaskGroup(of: Void.self) { group in
            for deck in MojiWordDeck.allCases {
                let target = repository(for: deck)
                group.addTask {
                    let seed = await target.activate()
                    await MainActor.run {
                        MojiWordPresentation.shared.publish(seed, deck: deck)
                    }
                }
            }
        }
    }

    func refreshClock() async {
        for deck in MojiWordDeck.allCases {
            await repository(for: deck).refreshClock()
        }
    }

    func flush() async {
        for deck in MojiWordDeck.allCases {
            await repository(for: deck).flush()
        }
    }

    func reloadFromDisk() async {
        for deck in MojiWordDeck.allCases {
            await repository(for: deck).reloadFromDisk()
        }
    }
}

@MainActor
final class MojiWordDomainRegistry {
    static let shared = MojiWordDomainRegistry()

    private(set) var active: MojiWordDomain?

    private init() {}

    func install(_ domain: MojiWordDomain) {
        active = domain
    }

    func requireDomain() async -> MojiWordDomain {
        if let active {
            return active
        }
        return await MojiEngineRuntime.shared.prepareWords().value
    }
}
