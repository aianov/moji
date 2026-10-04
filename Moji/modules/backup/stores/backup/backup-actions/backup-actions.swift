import Foundation
import Observation

@MainActor
@Observable
final class BackupActionsStore {
    static let shared = BackupActionsStore()

    private var repository: MojiBackupRepository { .shared }
    private var runtime: MojiEngineRuntime { .shared }

    private init() {}

    func exportAction() async throws -> MojiBackupExport {
        await runtime.flushAll()
        return try await repository.export(now: Date())
    }

    func inspectAction(_ url: URL) async throws -> MojiBackupPreview {
        try await repository.inspect(fileAt: url)
    }

    func importAction(_ preview: MojiBackupPreview) async throws -> MojiBackupManifest? {
        let repository = repository
        let data = preview.data
        return try await runtime.replaceData {
            try await repository.restore(data, now: Date())
        }
    }

    func undoAction() async throws {
        let repository = repository
        try await runtime.replaceData {
            try await repository.undo()
        }
    }

    func safetyCopyAction() async -> MojiBackupManifest? {
        await repository.safetyCopy()
    }
}
