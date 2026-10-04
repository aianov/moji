import Foundation

actor MojiLearnDomain {
    nonisolated let repository: MojiLearnRepository

    private var isActive = false

    init(
        store: MojiDiskStore,
        planner: MojiLearnPlanner
    ) {
        repository = MojiLearnRepository(
            resources: MojiLearnResourceRepository(store: store),
            planner: planner
        )
    }

    func activate() async {
        guard !isActive else { return }
        isActive = true

        await MainActor.run {
            MojiLearnDomainRegistry.shared.install(self)
        }
        await repository.setPublisher { snapshot in
            await MainActor.run {
                MojiLearnPresentation.shared.publish(snapshot)
            }
        }
        let seed = await repository.activate()
        await MainActor.run {
            MojiLearnPresentation.shared.publish(seed)
        }
    }

    func refreshClock() async {
        await repository.refreshClock()
    }

    func reloadFromDisk() async {
        await repository.reloadFromDisk()
    }
}

@MainActor
final class MojiLearnDomainRegistry {
    static let shared = MojiLearnDomainRegistry()

    private(set) var active: MojiLearnDomain?

    private init() {}

    func install(_ domain: MojiLearnDomain) {
        active = domain
    }

    func requireDomain() async -> MojiLearnDomain {
        if let active {
            return active
        }
        return await MojiEngineRuntime.shared.prepareLearn().value
    }
}
