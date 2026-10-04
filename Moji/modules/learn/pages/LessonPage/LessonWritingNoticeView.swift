import SwiftUI

struct LessonWritingNoticeView: View {
    let onContinue: () -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 18) {
                Image(systemName: "pencil.and.scribble")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(MojiTint.gold)
                    .frame(width: 92, height: 92)
                    .liquidChromeCircle(interactive: false)

                Text("Writing is left")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(theme.text.primary)
                    .multilineTextAlignment(.center)

                Text("Complete the writing part to fill this group up to 100%. The pencil is on the right of the group's row.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.text.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 24)

            ProgressCapsuleButton(
                title: String(localized: "Continue"),
                role: .primary,
                action: onContinue
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
    }
}
