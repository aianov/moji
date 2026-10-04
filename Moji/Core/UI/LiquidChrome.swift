import SwiftUI

enum LiquidChrome {
    static func glass(tint: Color?, interactive: Bool) -> Glass {
        Glass.regular
            .tint(tint)
            .interactive(interactive)
    }
}

extension View {
    func liquidChromeCapsule(
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        glassEffect(
            LiquidChrome.glass(tint: tint, interactive: interactive),
            in: Capsule(style: .continuous)
        )
    }

    func liquidChromeRoundedRectangle(
        cornerRadius: CGFloat,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        glassEffect(
            LiquidChrome.glass(tint: tint, interactive: interactive),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    func liquidChromeCircle(
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        glassEffect(
            LiquidChrome.glass(tint: tint, interactive: interactive),
            in: Circle()
        )
    }
}
