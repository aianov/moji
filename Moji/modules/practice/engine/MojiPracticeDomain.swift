import Foundation

actor MojiPracticeDomain {
    nonisolated let repository: MojiPracticeRepository

    private var isActive = false

    init(
        store: MojiDiskStore,
        catalog: MojiAlphabetCatalog
    ) {
        repository = MojiPracticeRepository(
            resources: MojiPracticeResourceRepository(store: store),
            catalog: catalog
        )
    }

    func activate() async {
        guard !isActive else { return }
        isActive = true

        await MainActor.run {
            MojiPracticeDomainRegistry.shared.install(self)
        }
        await repository.setPublisher { snapshot in
            await MainActor.run {
                MojiPracticePresentation.shared.publish(snapshot)
            }
        }
        let seed = await repository.activate()
        await MainActor.run {
            MojiPracticePresentation.shared.publish(seed)
        }
    }

    func refreshClock() async {
        await repository.refreshClock()
    }
}

@MainActor
final class MojiPracticeDomainRegistry {
    static let shared = MojiPracticeDomainRegistry()

    private(set) var active: MojiPracticeDomain?

    private init() {}

    func install(_ domain: MojiPracticeDomain) {
        active = domain
    }

    func requireDomain() async -> MojiPracticeDomain {
        if let active {
            return active
        }
        return await MojiEngineRuntime.shared.preparePractice().value
    }
}
