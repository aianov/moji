import Foundation

actor MojiNoteDomain {
    nonisolated let repository: MojiNoteRepository

    private var isActive = false

    init(store: MojiDiskStore) {
        repository = MojiNoteRepository(
            resources: MojiNoteResourceRepository(store: store)
        )
    }

    func activate() async {
        guard !isActive else { return }
        isActive = true

        await MainActor.run {
            MojiNoteDomainRegistry.shared.install(self)
        }
        await repository.setPublisher { snapshot in
            await MainActor.run {
                MojiNotePresentation.shared.publish(snapshot)
            }
        }
        let seed = await repository.activate()
        await MainActor.run {
            MojiNotePresentation.shared.publish(seed)
        }
    }

    func reloadFromDisk() async {
        guard isActive else {
            await activate()
            return
        }
        await repository.reloadFromDisk()
    }
}

@MainActor
final class MojiNoteDomainRegistry {
    static let shared = MojiNoteDomainRegistry()

    private(set) var active: MojiNoteDomain?

    private init() {}

    func install(_ domain: MojiNoteDomain) {
        active = domain
    }

    func requireDomain() async -> MojiNoteDomain {
        if let active {
            return active
        }
        return await MojiEngineRuntime.shared.prepareNotes().value
    }
}
