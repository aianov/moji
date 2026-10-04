import Foundation
import Observation

@MainActor
@Observable
final class BackupServicesStore {
    static let shared = BackupServicesStore()

    var activity: BackupActivity?
    var exportDocument: BackupFileDocument?
    var exportFilename = ""
    var isExporterPresented = false
    var isImporterPresented = false
    var pendingImport: MojiBackupPreview?
    var safetyCopy: MojiBackupManifest?
    var isUndoConfirmPresented = false
    var failure: BackupFailure?

    private init() {}

    var isBusy: Bool {
        activity != nil
    }

    func importSummary(_ manifest: MojiBackupManifest) -> String {
        let counts = manifest.counts
        var lines = [
            String(localized: "Exported \(manifest.exportedAt.formatted(date: .abbreviated, time: .shortened))"),
            String(localized: "Characters with progress: \(counts.characters)"),
            String(localized: "Word cards studied: \(counts.wordCards)")
        ]
        if let ownCards = counts.ownCards {
            lines.append(String(localized: "Own cards: \(ownCards)"))
        }
        if let notes = counts.notes {
            lines.append(String(localized: "Notes: \(notes)"))
        }
        lines.append("")
        lines.append(String(localized: "This replaces all data on this iPhone. The current data is kept, so you can undo the import here."))
        return lines.joined(separator: "\n")
    }

    func undoSummary(_ manifest: MojiBackupManifest) -> String {
        String(localized: "The data this iPhone had before the import on \(manifest.exportedAt.formatted(date: .abbreviated, time: .shortened)) comes back. Anything changed since then is lost.")
    }
}
