import SwiftUI

struct ProgressBarUi<Fill: ShapeStyle>: View {
    let progress: Double
    var height: CGFloat = 8
    var track: Color? = nil
    let fill: Fill

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    private var clamped: Double {
        guard progress.isFinite else { return 0 }
        return min(1, max(0, progress))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(track ?? theme.bg._500)

                if clamped > 0 {
                    Capsule(style: .continuous)
                        .fill(fill)
                        .frame(width: max(height, geometry.size.width * clamped))
                }
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: clamped)
        .accessibilityElement()
        .accessibilityValue(Text("\(Int((clamped * 100).rounded()))%"))
    }
}
