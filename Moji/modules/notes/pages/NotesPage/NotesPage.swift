import SwiftUI

struct NotesPage: View {
    private var service: NotesServicesStore { .shared }
    private var interactions: NotesInteractionsStore { .shared }

    var body: some View {
        let path = Binding(
            get: { service.path },
            set: { interactions.setPath($0) }
        )
        let sheet = Binding(
            get: { service.sheet },
            set: { if $0 == nil { interactions.closeSheet() } }
        )

        NavigationStack(path: path) {
            NotesHome()
                .toolbarVisibility(.hidden, for: .navigationBar)
                .navigationDestination(for: NotesRoute.self) { route in
                    switch route {
                    case .note(let noteID):
                        NoteEditorView(noteID: noteID)
                    }
                }
        }
        .sheet(item: sheet) { sheet in
            Group {
                switch sheet {
                case .folders:
                    NotesFoldersSheet()
                case .move(let noteID):
                    NotesMoveSheet(noteID: noteID)
                }
            }
            .notesFolderAlerts(isActive: true)
            .themedPresentation()
        }
        .notesFolderAlerts(isActive: service.sheet == nil)
        .onChange(of: service.snapshot.generation) {
            interactions.syncAfterReload()
        }
    }
}

private struct NotesHome: View {
    private var service: NotesServicesStore { .shared }
    private var interactions: NotesInteractionsStore { .shared }

    var body: some View {
        VStack(spacing: 12) {
            NotesHeader()
                .padding(.horizontal, 16)

            NotesSearchField(text: service.query) { interactions.setQuery($0) }
                .padding(.horizontal, 16)

            if !service.isSearching {
                NotesFolderBar()
                    .transition(.opacity)
            }

            NotesList()
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .padding(.top, 6)
        .background {
            AppBackground()
        }
        .overlay(alignment: .bottom) {
            NotesUndoToast()
        }
        .animation(.snappy(duration: 0.25), value: service.isSearching)
    }
}

private struct NotesList: View {
    private var service: NotesServicesStore { .shared }

    var body: some View {
        Group {
            if !service.isLoaded {
                Color.clear
            } else if service.isSearching {
                searchResults
            } else {
                folderNotes
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var folderNotes: some View {
        let notes = service.visibleNotes
        if notes.isEmpty {
            NotesEmptyState(kind: service.selectedFolder == nil ? .noNotes : .emptyFolder)
        } else {
            let pinned = notes.filter(\.isPinned)
            let others = notes.filter { !$0.isPinned }
            let showsFolder = service.selectedFolder == nil

            List {
                if !pinned.isEmpty {
                    Section {
                        ForEach(pinned) { note in
                            NotesListRow(note: note, showsFolder: showsFolder)
                        }
                    } header: {
                        NotesSectionHeader(title: String(localized: "Pinned"))
                    }
                }
                if !others.isEmpty {
                    Section {
                        ForEach(others) { note in
                            NotesListRow(note: note, showsFolder: showsFolder)
                        }
                    } header: {
                        if !pinned.isEmpty {
                            NotesSectionHeader(title: String(localized: "Notes"))
                        }
                    }
                }
            }
            .notesListStyle()
            .animation(.snappy(duration: 0.3), value: notes.map(\.id))
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        let hits = service.searchResults()
        if hits.isEmpty {
            NotesEmptyState(kind: .noResults)
        } else {
            let terms = service.searchTerms
            List {
                Section {
                    ForEach(hits) { hit in
                        NotesListRow(note: hit.note, showsFolder: true, snippet: hit.snippet, terms: terms)
                    }
                } header: {
                    NotesSectionHeader(title: String(localized: "\(hits.count) notes"))
                }
            }
            .notesListStyle()
        }
    }
}

private struct NotesListRow: View {
    let note: MojiNote
    let showsFolder: Bool
    var snippet: String? = nil
    var terms: [String] = []

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: NotesServicesStore { .shared }
    private var interactions: NotesInteractionsStore { .shared }

    static let pinTint = Color(hex: "#8E8E93")
    static let moveTint = Color(hex: "#5A5A5E")

    var body: some View {
        Button {
            interactions.openNote(note)
        } label: {
            NoteRow(
                note: note,
                folderName: showsFolder ? service.folderName(of: note) : nil,
                snippet: snippet,
                terms: terms
            )
        }
        .listRowBackground(theme.bg._300)
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        .listRowSeparatorTint(theme.border._200.opacity(theme.isDark ? 1 : 0.6))
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                interactions.togglePin(note)
            } label: {
                if note.isPinned {
                    Label("Unpin", systemImage: "pin.slash.fill")
                } else {
                    Label("Pin", systemImage: "pin.fill")
                }
            }
            .tint(Self.pinTint)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                interactions.delete(note)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(MojiTint.wrong)
            Button {
                interactions.requestMove(note.id)
            } label: {
                Label("Move", systemImage: "folder")
            }
            .tint(Self.moveTint)
        }
        .contextMenu {
            Button {
                interactions.togglePin(note)
            } label: {
                if note.isPinned {
                    Label("Unpin", systemImage: "pin.slash")
                } else {
                    Label("Pin", systemImage: "pin")
                }
            }
            Button {
                interactions.requestMove(note.id)
            } label: {
                Label("Move to folder", systemImage: "folder")
            }
            Divider()
            Button(role: .destructive) {
                interactions.delete(note)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private extension View {
    func notesListStyle() -> some View {
        listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .contentMargins(.top, 2, for: .scrollContent)
            .listSectionSpacing(14)
            .scrollDismissesKeyboard(.immediately)
    }
}
