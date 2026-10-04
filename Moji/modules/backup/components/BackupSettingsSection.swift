import SwiftUI
import UniformTypeIdentifiers

struct BackupSettingsSection: View {
    private var service: BackupServicesStore { .shared }
    private var interactions: BackupInteractionsStore { .shared }

    var body: some View {
        let isExporterPresented = Binding(
            get: { service.isExporterPresented },
            set: { interactions.setExporterPresented($0) }
        )
        let isImporterPresented = Binding(
            get: { service.isImporterPresented },
            set: { interactions.setImporterPresented($0) }
        )

        Section {
            Button {
                interactions.exportData()
            } label: {
                BackupRowLabel(title: "Export my data", isWorking: service.activity == .exporting)
            }
            .disabled(service.isBusy)
            .fileExporter(
                isPresented: isExporterPresented,
                document: service.exportDocument,
                contentTypes: [.json],
                defaultFilename: service.exportFilename,
                onCompletion: { interactions.exportDidFinish($0) },
                onCancellation: { interactions.exportDidCancel() }
            )

            Button {
                interactions.importData()
            } label: {
                BackupRowLabel(
                    title: "Import data",
                    isWorking: service.activity == .reading || service.activity == .importing
                )
            }
            .disabled(service.isBusy)
            .fileImporter(
                isPresented: isImporterPresented,
                allowedContentTypes: [.json],
                onCompletion: { interactions.importDidPick($0) }
            )

            if let copy = service.safetyCopy {
                Button {
                    interactions.requestUndo()
                } label: {
                    BackupRowLabel(
                        title: "Undo import",
                        detail: copy.exportedAt.formatted(date: .abbreviated, time: .shortened),
                        isWorking: service.activity == .undoing
                    )
                }
                .disabled(service.isBusy)
            }
        } header: {
            Text("Data")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Export saves your progress, word cards, notes and settings to one file. Import it on another iPhone to move everything over.")
                if service.safetyCopy != nil {
                    Text("Undo import brings back the data this iPhone had before the last import.")
                }
            }
        }
    }
}

private struct BackupRowLabel: View {
    let title: LocalizedStringKey
    var detail: String?
    let isWorking: Bool

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer(minLength: 8)
            if isWorking {
                ProgressView()
            } else if let detail {
                Text(verbatim: detail)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.text.secondary)
            }
        }
    }
}

struct BackupPresentations: ViewModifier {
    private var service: BackupServicesStore { .shared }
    private var interactions: BackupInteractionsStore { .shared }

    func body(content: Content) -> some View {
        let isImportConfirmPresented = Binding(
            get: { service.pendingImport != nil },
            set: { if !$0 { interactions.cancelImport() } }
        )
        let isUndoConfirmPresented = Binding(
            get: { service.isUndoConfirmPresented },
            set: { if !$0 { interactions.cancelUndo() } }
        )
        let isFailurePresented = Binding(
            get: { service.failure != nil },
            set: { if !$0 { interactions.dismissFailure() } }
        )

        content
            .task {
                interactions.dataSectionDidAppear()
            }
            .alert(
                "Import this backup?",
                isPresented: isImportConfirmPresented,
                presenting: service.pendingImport
            ) { _ in
                Button("Replace data", role: .destructive) {
                    interactions.confirmImport()
                }
                Button("Cancel", role: .cancel) {
                    interactions.cancelImport()
                }
            } message: { preview in
                Text(verbatim: service.importSummary(preview.manifest))
            }
            .alert(
                "Undo the import?",
                isPresented: isUndoConfirmPresented,
                presenting: service.safetyCopy
            ) { _ in
                Button("Undo import", role: .destructive) {
                    interactions.confirmUndo()
                }
                Button("Cancel", role: .cancel) {
                    interactions.cancelUndo()
                }
            } message: { copy in
                Text(verbatim: service.undoSummary(copy))
            }
            .alert(
                service.failure?.title ?? "",
                isPresented: isFailurePresented,
                presenting: service.failure
            ) { _ in
                Button("OK", role: .cancel) {
                    interactions.dismissFailure()
                }
            } message: { failure in
                Text(verbatim: failure.message)
            }
    }
}

extension View {
    func backupPresentations() -> some View {
        modifier(BackupPresentations())
    }
}
