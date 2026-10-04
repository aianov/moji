import SwiftUI

struct NotesSearchField: View {
    let text: String
    let onChange: (String) -> Void

    @FocusState private var isFocused: Bool

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let binding = Binding(get: { text }, set: { onChange($0) })

        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.text.secondary)
                .frame(width: 24, height: CharacterSearchField.height)
                .contentShape(Rectangle())
                .onTapGesture { isFocused = true }
                .accessibilityHidden(true)

            TextField(String(localized: "Search notes"), text: binding)
                .font(.system(size: 16))
                .typesettingLanguage(Locale.Language(identifier: "ja"))
                .foregroundStyle(theme.text.primary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFocused)
                .frame(maxWidth: .infinity)
                .frame(height: CharacterSearchField.height)
                .accessibilityLabel(Text("Search notes"))

            if !text.isEmpty {
                Button {
                    onChange("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(theme.text.secondary.opacity(0.8))
                        .frame(width: 34, height: CharacterSearchField.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear search"))
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, text.isEmpty ? 14 : 4)
        .frame(height: CharacterSearchField.height)
        .liquidChromeCapsule()
        .animation(.snappy(duration: 0.22), value: text.isEmpty)
    }
}
