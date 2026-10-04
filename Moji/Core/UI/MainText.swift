import SwiftUI

enum TextAlignT {
    case left
    case center
    case right

    var textAlignment: TextAlignment {
        switch self {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        }
    }
}

struct MainText: View {
    let text: String
    var px: CGFloat = 16
    var tac: TextAlignT = .left
    var fontWeight: Font.Weight = .regular
    var design: Font.Design = .default
    var color: Color? = nil
    var primary: Bool = false
    var secondary: Bool = false
    var numberOfLines: Int = 0
    var monospacedDigits: Bool = false

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let resolvedColor: Color = {
            if primary { return theme.primary._100 }
            if secondary { return theme.text.secondary }
            return color ?? theme.text.primary
        }()
        let font = Font.system(size: px, weight: fontWeight, design: design)

        Text(text)
            .font(monospacedDigits ? font.monospacedDigit() : font)
            .foregroundStyle(resolvedColor)
            .multilineTextAlignment(tac.textAlignment)
            .lineLimit(numberOfLines == 0 ? nil : numberOfLines)
    }
}

struct SecondaryText: View {
    let text: String
    var px: CGFloat = 15
    var tac: TextAlignT = .left
    var fontWeight: Font.Weight = .regular
    var color: Color? = nil
    var numberOfLines: Int = 0

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        Text(text)
            .font(.system(size: px, weight: fontWeight))
            .foregroundStyle(color ?? theme.text.secondary)
            .multilineTextAlignment(tac.textAlignment)
            .lineLimit(numberOfLines == 0 ? nil : numberOfLines)
    }
}

struct GlyphText: View {
    let text: String
    var size: CGFloat
    var weight: Font.Weight = .regular
    var color: Color? = nil
    var minimumScale: CGFloat = 0.4

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        Text(text)
            .typesettingLanguage(Locale.Language(identifier: "ja"))
            .font(.system(size: size, weight: weight))
            .foregroundStyle(color ?? theme.text.primary)
            .lineLimit(1)
            .minimumScaleFactor(minimumScale)
    }
}
