import Foundation

actor MojiWordDomain {
    nonisolated let repository: MojiWordRepository

    private var isActive = false

    init(store: MojiDiskStore) {
        repository = MojiWordRepository(
            resources: MojiWordResourceRepository(store: store)
        )
    }

    func activate() async {
        guard !isActive else { return }
        isActive = true

        await MainActor.run {
            MojiWordDomainRegistry.shared.install(self)
        }
        await repository.setPublisher { snapshot in
            await MainActor.run {
                MojiWordPresentation.shared.publish(snapshot)
            }
        }
        let seed = await repository.activate()
        await MainActor.run {
            MojiWordPresentation.shared.publish(seed)
        }
    }

    func refreshClock() async {
        await repository.refreshClock()
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
