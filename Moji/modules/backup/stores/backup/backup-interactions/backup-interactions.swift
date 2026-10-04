import Foundation
import Observation

@MainActor
@Observable
final class BackupInteractionsStore {
    static let shared = BackupInteractionsStore()

    static let presentationHandoff: Duration = .milliseconds(450)

    private var actions: BackupActionsStore { .shared }
    private var service: BackupServicesStore { .shared }

    private init() {}

    func dataSectionDidAppear() {
        Task {
            let copy = await actions.safetyCopyAction()
            guard !service.isBusy else { return }
            service.safetyCopy = copy
        }
    }

    func exportData() {
        guard !service.isBusy else { return }
        MojiHaptics.selection()
        service.activity = .exporting
        Task {
            do {
                let export = try await actions.exportAction()
                service.exportFilename = export.filename
                service.exportDocument = BackupFileDocument(data: export.data)
                service.activity = nil
                service.isExporterPresented = true
            } catch {
                service.activity = nil
                fail(.export)
            }
        }
    }

    func setExporterPresented(_ isPresented: Bool) {
        service.isExporterPresented = isPresented
    }

    func exportDidFinish(_ result: Result<URL, any Error>) {
        let closedAt = ContinuousClock.now
        service.isExporterPresented = false
        service.exportDocument = nil
        switch result {
        case .success:
            MojiHaptics.success()
        case .failure:
            Task {
                await fail(.export, after: closedAt)
            }
        }
    }

    func exportDidCancel() {
        service.isExporterPresented = false
        service.exportDocument = nil
    }

    func importData() {
        guard !service.isBusy else { return }
        MojiHaptics.selection()
        service.isImporterPresented = true
    }

    func setImporterPresented(_ isPresented: Bool) {
        service.isImporterPresented = isPresented
    }

    func importDidPick(_ result: Result<URL, any Error>) {
        let closedAt = ContinuousClock.now
        service.isImporterPresented = false
        guard case .success(let url) = result else {
            Task {
                await fail(.importing(.unreadable), after: closedAt)
            }
            return
        }
        service.activity = .reading
        Task {
            do {
                let preview = try await actions.inspectAction(url)
                try? await Task.sleep(until: closedAt.advanced(by: Self.presentationHandoff), clock: .continuous)
                service.activity = nil
                service.pendingImport = preview
            } catch {
                service.activity = nil
                await fail(.importing(error as? MojiBackupError ?? .unreadable), after: closedAt)
            }
        }
    }

    func confirmImport() {
        guard let preview = service.pendingImport, !service.isBusy else { return }
        let closedAt = ContinuousClock.now
        service.pendingImport = nil
        service.activity = .importing
        Task {
            do {
                let copy = try await actions.importAction(preview)
                refreshAfterReplace()
                service.safetyCopy = copy
                service.activity = nil
                MojiHaptics.success()
            } catch {
                service.activity = nil
                await fail(.importing(error as? MojiBackupError ?? .writeFailed), after: closedAt)
            }
        }
    }

    func cancelImport() {
        service.pendingImport = nil
    }

    func requestUndo() {
        guard !service.isBusy, service.safetyCopy != nil else { return }
        MojiHaptics.selection()
        service.isUndoConfirmPresented = true
    }

    func confirmUndo() {
        let closedAt = ContinuousClock.now
        service.isUndoConfirmPresented = false
        guard !service.isBusy else { return }
        service.activity = .undoing
        Task {
            do {
                try await actions.undoAction()
                refreshAfterReplace()
                service.safetyCopy = nil
                service.activity = nil
                MojiHaptics.success()
            } catch {
                service.safetyCopy = await actions.safetyCopyAction()
                service.activity = nil
                await fail(.undo(error as? MojiBackupError ?? .writeFailed), after: closedAt)
            }
        }
    }

    func cancelUndo() {
        service.isUndoConfirmPresented = false
    }

    func dismissFailure() {
        service.failure = nil
    }

    private func refreshAfterReplace() {
        ThemeStore.shared.reloadFromDefaults()
        MojiPreferencesStore.shared.reloadFromDefaults()
        LearnServicesStore.shared.reloadFromDefaults()
        AlphabetServicesStore.shared.reloadFromDefaults()
        SearchInteractionsStore.shared.activePageDidChange(on: .learn)
        SearchInteractionsStore.shared.activePageDidChange(on: .practice)
        WordsInteractionsStore.shared.syncAfterReload()
        NotesInteractionsStore.shared.syncAfterReload()
        ProfileServicesStore.shared.selectedDayKey = nil
    }

    private func fail(_ failure: BackupFailure) {
        service.failure = failure
        MojiHaptics.error()
    }

    private func fail(_ failure: BackupFailure, after closedAt: ContinuousClock.Instant) async {
        try? await Task.sleep(until: closedAt.advanced(by: Self.presentationHandoff), clock: .continuous)
        fail(failure)
    }
}
