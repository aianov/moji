import Foundation

extension NotesInteractionsStore {
    static let saveDelay: TimeInterval = 0.7
    static let maximumSaveWait: TimeInterval = 4
    static let countsDelay: Duration = .milliseconds(250)

    func updateTitle(_ text: String) -> Bool {
        guard var editor = openEditor else { return false }
        let movesToBody = text.contains(where: \.isNewline)
        let title = movesToBody ? text.split(whereSeparator: \.isNewline).joined(separator: " ") : text
        if editor.title != title {
            editor.title = title
            service.editor = editor
            scheduleSave()
        }
        return movesToBody
    }

    func updateBody(_ text: String) {
        guard var editor = openEditor, editor.body != text else { return }
        editor.body = text
        service.editor = editor
        scheduleSave()
        scheduleCounts(text)
    }

    func flushEditor() {
        cancelPendingSave()
        guard let editor = openEditor, editor.isDirty else { return }
        persist(editor)
    }

    func closeEditor(_ noteID: String) {
        guard let editor = service.editor, editor.noteID == noteID else { return }
        settle(editor)
        enqueue {
            if editor.isDirty {
                _ = await self.actions.saveNoteAction(editor)
            }
            await self.actions.discardIfEmptyAction(noteID)
        }
    }

    func editorDidDisappear(_ noteID: String) {
        if service.path.contains(.note(noteID)) {
            flushEditor()
        } else if service.editor?.noteID == noteID {
            service.editor = nil
        }
    }

    func togglePinOpenNote() {
        guard let note = service.editedNote else { return }
        togglePin(note)
    }

    func requestMoveOpenNote() {
        guard let editor = openEditor else { return }
        requestMove(editor.noteID)
    }

    func deleteOpenNote() {
        guard let editor = openEditor, editor.isPersisted else { return }
        settle(editor)
        service.path = []
        MojiHaptics.impact()
        enqueue {
            if editor.isDirty {
                _ = await self.actions.saveNoteAction(editor)
            }
            guard let removed = await self.actions.deleteNoteAction(editor.noteID), !removed.isBlank else { return }
            self.showUndo(removed)
        }
    }

    func reseedEditorAfterReload() {
        guard let editor = service.editor else { return }
        cancelPendingSave()
        if let note = service.snapshot.note(editor.noteID) {
            service.editor = NotesEditorState(note: note)
            scheduleCounts(note.body)
        } else if editor.isPersisted {
            settle(editor)
            service.path = []
        }
    }

    private var openEditor: NotesEditorState? {
        guard let editor = service.editor, service.path.contains(.note(editor.noteID)) else { return nil }
        return editor
    }

    private func settle(_ editor: NotesEditorState) {
        cancelPendingSave()
        countsTask?.cancel()
        var settled = editor
        settled.savedTitle = editor.title
        settled.savedBody = editor.body
        service.editor = settled
    }

    private func scheduleSave() {
        let now = Date()
        let since = pendingSince ?? now
        pendingSince = since
        let delay = max(0, min(Self.saveDelay, Self.maximumSaveWait - now.timeIntervalSince(since)))
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            saveTask = nil
            pendingSince = nil
            guard let editor = openEditor, editor.isDirty else { return }
            persist(editor)
        }
    }

    private func cancelPendingSave() {
        saveTask?.cancel()
        saveTask = nil
        pendingSince = nil
    }

    private func persist(_ editor: NotesEditorState) {
        enqueue {
            let saved = await self.actions.saveNoteAction(editor)
            self.markSaved(editor, persisted: saved != nil)
        }
    }

    private func markSaved(_ saved: NotesEditorState, persisted: Bool) {
        guard var current = openEditor, current.noteID == saved.noteID else { return }
        current.savedTitle = saved.title
        current.savedBody = saved.body
        if persisted {
            current.isPersisted = true
        }
        guard current != service.editor else { return }
        service.editor = current
    }

    private func enqueue(_ work: @escaping @MainActor @Sendable () async -> Void) {
        let previous = saveChain
        saveChain = Task {
            await previous?.value
            await work()
        }
    }

    private func scheduleCounts(_ text: String) {
        countsTask?.cancel()
        countsTask = Task {
            try? await Task.sleep(for: Self.countsDelay)
            guard !Task.isCancelled else { return }
            let counts = await Task.detached(priority: .utility) {
                MojiNoteText.counts(text)
            }.value
            guard !Task.isCancelled else { return }
            service.editorCounts = counts
        }
    }
}
