import Foundation

struct MojiNoteResourceRepository: Sendable {
    static let version = 1
    static let libraryKey = MojiDiskKey(namespace: "notes", name: "library")

    let store: MojiDiskStore

    func load() async -> MojiNoteLibrary {
        await store.read(
            MojiNoteLibrary.self,
            key: Self.libraryKey,
            version: Self.version
        ) ?? .empty
    }

    func save(_ library: MojiNoteLibrary) async {
        await store.write(
            library,
            key: Self.libraryKey,
            version: Self.version
        )
    }
}
