import SwiftUI

struct WritingPracticeRequest: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let characters: [MojiCharacter]

    static func == (lhs: WritingPracticeRequest, rhs: WritingPracticeRequest) -> Bool {
        lhs.id == rhs.id
    }

    static func available(_ characters: [MojiCharacter]) -> [MojiCharacter] {
        guard let library = MojiStrokeLibrary.shared else { return [] }
        return characters.filter { library.glyphs($0.glyph) != nil }
    }
}

struct WritingPracticeView: View {
    let request: WritingPracticeRequest
    var onFinish: (([MojiWritingCard]) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WritingServicesStore { .shared }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.text.primary)
                        .frame(width: 40, height: 40)
                        .contentShape(Circle())
                        .liquidChromeCircle(interactive: true)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(Text("Close"))

                Text(request.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.text.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)

                Color.clear
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            WritingBlockView()

            if service.isFinished || service.isUnavailable {
                ProgressCapsuleButton(
                    title: String(localized: "Done"),
                    role: .primary,
                    action: { dismiss() }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .transition(.opacity)
            }
        }
        .background {
            AppBackground()
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: service.isFinished)
        .onAppear {
            let finish = onFinish
            WritingInteractionsStore.shared.start(request.characters) { cards in
                finish?(cards)
            }
        }
        .onDisappear {
            WritingInteractionsStore.shared.stop()
        }
    }
}
