import SwiftUI

struct NoteRow: View {
    let note: MojiNote
    let folderName: String?
    var snippet: String? = nil
    var terms: [String] = []

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let heading = MojiNoteText.heading(title: note.title, body: note.body)
        let preview = snippet ?? MojiNoteText.preview(title: note.title, body: note.body)

        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.text.secondary)
                        .accessibilityLabel(Text("Pinned note"))
                }
                Text(verbatim: heading ?? String(localized: "New note"))
                    .font(.system(size: 16, weight: .semibold))
                    .typesettingLanguage(Locale.Language(identifier: "ja"))
                    .foregroundStyle(heading == nil ? theme.text.secondary : theme.text.primary)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: NotesFormat.date(note.updatedAt))
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(theme.text.secondary)
                    .lineLimit(1)
                    .fixedSize()
                if let preview {
                    NotesHighlightedText(text: preview, terms: terms)
                        .lineLimit(1)
                }
            }

            if let folderName {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                    Text(verbatim: folderName)
                        .typesettingLanguage(Locale.Language(identifier: "ja"))
                        .lineLimit(1)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.text.secondary.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct NotesHighlightedText: View {
    let text: String
    let terms: [String]
    var size: CGFloat = 13

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        Text(attributed)
            .font(.system(size: size))
            .typesettingLanguage(Locale.Language(identifier: "ja"))
            .foregroundStyle(theme.text.secondary)
    }

    private var attributed: AttributedString {
        guard !terms.isEmpty else { return AttributedString(text) }
        var result = AttributedString()
        for segment in MojiNoteSearch.segments(of: text, terms: terms) {
            var part = AttributedString(segment.text)
            if segment.isMatch {
                part.font = .system(size: size, weight: .semibold)
                part.foregroundColor = theme.text.primary
            }
            result.append(part)
        }
        return result
    }
}

struct NotesSectionHeader: View {
    let title: String

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        Text(verbatim: title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(theme.text.secondary)
            .textCase(nil)
    }
}
