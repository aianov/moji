import SwiftUI

struct NotesUndoToast: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: NotesServicesStore { .shared }
    private var interactions: NotesInteractionsStore { .shared }

    var body: some View {
        if let undo = service.undo {
            HStack(spacing: 10) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.text.secondary)
                    .accessibilityHidden(true)
                Text("Note deleted")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.text.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button {
                    interactions.undoDelete()
                } label: {
                    Text("Undo")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.text.primary)
                        .padding(.horizontal, 8)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 18)
            .padding(.trailing, 10)
            .frame(height: 50)
            .liquidChromeCapsule()
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .id(undo.token)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
