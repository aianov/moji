import Foundation

struct MojiLearnResourceRepository: Sendable {
    private static let version = 1
    private static let stateKey = MojiDiskKey(namespace: "learn", name: "state")

    let store: MojiDiskStore

    func load() async -> MojiLearnState {
        await store.read(
            MojiLearnState.self,
            key: Self.stateKey,
            version: Self.version
        ) ?? .empty
    }

    func save(_ state: MojiLearnState) async {
        await store.write(
            state,
            key: Self.stateKey,
            version: Self.version
        )
    }

    func clear() async {
        await store.remove(Self.stateKey)
    }
}
