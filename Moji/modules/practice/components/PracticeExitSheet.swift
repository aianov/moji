import SwiftUI

struct PracticeExitSheet: View {
    let page: MojiPage

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: PracticeServicesStore { .shared }
    private var interactions: PracticeInteractionsStore { .shared }

    var body: some View {
        let answered = service.currentQuestion?.answeredCount(after: service.currentReveal) ?? 0
        let total = service.currentQuestion?.total ?? 0

        VStack(spacing: 0) {
            Text("Take a break?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(theme.text.primary)

            Text("Your place is saved: \(answered) of \(total) done. Continue any time from the \(page.title) page.")
                .font(.system(size: 15))
                .foregroundStyle(theme.text.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.horizontal, 12)

            VStack(spacing: 10) {
                ProgressCapsuleButton(
                    title: String(localized: "Keep practicing"),
                    role: .primary,
                    action: { interactions.keepPracticing() }
                )

                ProgressCapsuleButton(
                    title: String(localized: "Save and exit"),
                    role: .secondary,
                    action: { interactions.saveAndExit() }
                )

                Button(role: .destructive) {
                    interactions.discardAndExit()
                } label: {
                    Text("Discard session")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MojiTint.wrong)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 24)
        }
        .padding(.horizontal, 20)
        .padding(.top, 32)
        .padding(.bottom, 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(370)])
        .presentationDragIndicator(.visible)
    }
}
