import SwiftUI
import UIKit

struct NoteEditorView: View {
    static let autofocusDelay: Duration = .milliseconds(350)

    let noteID: String

    @FocusState private var isTitleFocused: Bool
    @State private var bodyFocusRequest = 0
    @State private var isBodyEditing = false
    @State private var didAutofocus = false
    @Environment(\.scenePhase) private var scenePhase

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: NotesServicesStore { .shared }
    private var interactions: NotesInteractionsStore { .shared }

    var body: some View {
        Group {
            if let editor = service.editor(for: noteID) {
                content(editor)
            } else {
                AppBackground()
            }
        }
        .toolbarVisibility(.hidden, for: .tabBar)
        .onDisappear {
            interactions.editorDidDisappear(noteID)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                interactions.flushEditor()
            }
        }
    }

    private func content(_ editor: NotesEditorState) -> some View {
        let title = Binding(
            get: { service.editor(for: noteID)?.title ?? "" },
            set: { value in
                if interactions.updateTitle(value) {
                    focusBody()
                }
            }
        )
        let isEditing = isTitleFocused || isBodyEditing

        return VStack(alignment: .leading, spacing: 0) {
            TextField(String(localized: "Title"), text: title, axis: .vertical)
                .font(.system(size: 26, weight: .bold))
                .typesettingLanguage(Locale.Language(identifier: "ja"))
                .foregroundStyle(theme.text.primary)
                .lineLimit(1...4)
                .submitLabel(.next)
                .focused($isTitleFocused)
                .onSubmit { focusBody() }
                .padding(.horizontal, NoteBodyTextView.horizontalInset)
                .padding(.top, 8)
                .padding(.bottom, 2)
                .accessibilityLabel(Text("Title"))

            NoteBodyTextView(
                text: editor.body,
                focusRequest: bodyFocusRequest,
                textColor: UIColor(theme.text.primary),
                onEdit: { interactions.updateBody($0) },
                onEditingChanged: { isBodyEditing = $0 }
            )
            .overlay(alignment: .topLeading) {
                if editor.body.isEmpty {
                    Text("Write anything you like")
                        .font(.body)
                        .foregroundStyle(theme.text.secondary.opacity(0.7))
                        .padding(.top, NoteBodyTextView.topInset)
                        .padding(.leading, NoteBodyTextView.horizontalInset)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
        .background {
            AppBackground()
        }
        .navigationTitle(folderTitle(editor))
        .navigationSubtitle(NotesFormat.counts(service.editorCounts))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NoteEditorMenu(editor: editor)
            }
            if isEditing {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismissKeyboard()
                    }
                }
            }
        }
        .task {
            await autofocus(editor)
        }
    }

    private func folderTitle(_ editor: NotesEditorState) -> String {
        service.snapshot.folder(editor.folderID)?.name ?? String(localized: "Notes")
    }

    private func focusBody() {
        isTitleFocused = false
        bodyFocusRequest += 1
    }

    private func dismissKeyboard() {
        isTitleFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func autofocus(_ editor: NotesEditorState) async {
        guard !didAutofocus else { return }
        didAutofocus = true
        guard editor.isFresh else {
            dismissKeyboard()
            return
        }
        try? await Task.sleep(for: Self.autofocusDelay)
        guard !Task.isCancelled else { return }
        isTitleFocused = true
    }
}

private struct NoteEditorMenu: View {
    let editor: NotesEditorState

    private var service: NotesServicesStore { .shared }
    private var interactions: NotesInteractionsStore { .shared }

    var body: some View {
        let isPinned = service.editedNote?.isPinned ?? false

        Menu {
            Button {
                interactions.togglePinOpenNote()
            } label: {
                if isPinned {
                    Label("Unpin", systemImage: "pin.slash")
                } else {
                    Label("Pin", systemImage: "pin")
                }
            }
            .disabled(!editor.isPersisted)
            Button {
                interactions.requestMoveOpenNote()
            } label: {
                Label("Move to folder", systemImage: "folder")
            }
            Divider()
            Button(role: .destructive) {
                interactions.deleteOpenNote()
            } label: {
                Label("Delete note", systemImage: "trash")
            }
            .disabled(!editor.isPersisted)
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(Text("Note actions"))
    }
}
