import SwiftUI

struct NotesFolderBar: View {
    static let chipTitleWidth: CGFloat = 180

    private var service: NotesServicesStore { .shared }
    private var interactions: NotesInteractionsStore { .shared }

    var body: some View {
        let folders = service.folders
        let selection = service.selectedFolderID
        let selectedChip: NotesFolderChipID = selection.map { .folder($0) } ?? .all

        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                GlassEffectContainer(spacing: GlassChipMetrics.spacing) {
                    HStack(spacing: GlassChipMetrics.spacing) {
                        NotesFolderChip(
                            title: String(localized: "All"),
                            isSelected: selection == nil,
                            action: { interactions.selectFolder(nil) }
                        )
                        .contextMenu {
                            NotesAllFolderMenuItems()
                        }
                        .id(NotesFolderChipID.all)

                        ForEach(Array(folders.enumerated()), id: \.element.id) { index, folder in
                            NotesFolderChip(
                                title: folder.name,
                                isSelected: selection == folder.id,
                                action: { interactions.selectFolder(folder.id) }
                            )
                            .contextMenu {
                                NotesFolderMenuItems(
                                    folder: folder,
                                    isFirst: index == 0,
                                    isLast: index == folders.count - 1
                                )
                            }
                            .id(NotesFolderChipID.folder(folder.id))
                        }

                        NotesNewFolderChip(showsTitle: folders.isEmpty)
                            .id(NotesFolderChipID.add)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
            .scrollIndicators(.hidden)
            .onAppear {
                proxy.scrollTo(selectedChip, anchor: .center)
            }
            .onChange(of: selectedChip) { _, chip in
                withAnimation(GlassChipMetrics.selectAnimation) {
                    proxy.scrollTo(chip, anchor: .center)
                }
            }
        }
        .frame(height: GlassChipMetrics.height + 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Folders"))
    }
}

private struct NotesFolderChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .typesettingLanguage(Locale.Language(identifier: "ja"))
                .lineLimit(1)
                .frame(maxWidth: NotesFolderBar.chipTitleWidth)
                .foregroundStyle(isSelected ? theme.bg._100 : theme.text.primary)
                .padding(.horizontal, 14)
                .frame(height: GlassChipMetrics.height)
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .glassChip(isSelected: isSelected, theme: theme)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}

private struct NotesNewFolderChip: View {
    let showsTitle: Bool

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: NotesInteractionsStore { .shared }

    var body: some View {
        Button {
            interactions.requestNewFolder(selectsFolder: true)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                if showsTitle {
                    Text("New folder")
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundStyle(theme.text.secondary)
            .padding(.horizontal, showsTitle ? 14 : 0)
            .frame(width: showsTitle ? nil : GlassChipMetrics.height, height: GlassChipMetrics.height)
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .liquidChromeCapsule(interactive: true)
        .accessibilityLabel(Text("New folder"))
    }
}

private struct NotesAllFolderMenuItems: View {
    private var interactions: NotesInteractionsStore { .shared }

    var body: some View {
        Button {
            interactions.requestNewFolder(selectsFolder: true)
        } label: {
            Label("New folder", systemImage: "folder.badge.plus")
        }
        Button {
            interactions.openFolderEditor()
        } label: {
            Label("Edit folders", systemImage: "list.bullet")
        }
    }
}

private struct NotesFolderMenuItems: View {
    let folder: MojiNoteFolder
    let isFirst: Bool
    let isLast: Bool

    private var interactions: NotesInteractionsStore { .shared }

    var body: some View {
        Button {
            interactions.requestRename(folder)
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button {
            interactions.shiftFolder(folder, by: -1)
        } label: {
            Label("Move left", systemImage: "arrow.left")
        }
        .disabled(isFirst)
        Button {
            interactions.shiftFolder(folder, by: 1)
        } label: {
            Label("Move right", systemImage: "arrow.right")
        }
        .disabled(isLast)
        Button {
            interactions.openFolderEditor()
        } label: {
            Label("Edit folders", systemImage: "list.bullet")
        }
        Divider()
        Button(role: .destructive) {
            interactions.requestDeleteFolder(folder)
        } label: {
            Label("Delete folder", systemImage: "trash")
        }
    }
}
