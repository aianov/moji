import SwiftUI

final class AppThemeValues: @unchecked Sendable {
    let bg000: Color
    let bg100: Color
    let bg200: Color
    let bg300: Color
    let bg400: Color
    let bg500: Color
    let bg600: Color
    let bg700: Color

    let border100: Color
    let border200: Color
    let border300: Color
    let border400: Color
    let border500: Color
    let border600: Color

    let btnBg000: Color
    let btnBg100: Color
    let btnBg200: Color
    let btnBg300: Color
    let btnBg400: Color
    let btnBg500: Color
    let btnBg600: Color

    let btnHeight100: CGFloat
    let btnHeight200: CGFloat
    let btnHeight300: CGFloat
    let btnHeight400: CGFloat
    let btnHeight500: CGFloat
    let btnHeight600: CGFloat

    let btnRadius000: CGFloat
    let btnRadius100: CGFloat
    let btnRadius200: CGFloat
    let btnRadius300: CGFloat

    let primary100: Color
    let primary200: Color
    let primary300: Color

    let success100: Color
    let success200: Color
    let success300: Color
    let error100: Color
    let error200: Color
    let error300: Color

    let text100: Color
    let secondary100: Color

    let inputBg100: Color
    let inputBg200: Color
    let inputBg300: Color
    let inputBorder300: Color
    let inputHeight300: CGFloat
    let inputRadius300: CGFloat

    let radius100: CGFloat
    let radius200: CGFloat
    let radius300: CGFloat
    let radius400: CGFloat
    let radius500: CGFloat
    let radius600: CGFloat

    let gradientPrimary: LinearGradient

    init(palette p: ThemePalette) {
        bg000 = Color(hex: p.bg000)
        bg100 = Color(hex: p.bg100)
        bg200 = Color(hex: p.bg200)
        bg300 = Color(hex: p.bg300)
        bg400 = Color(hex: p.bg400)
        bg500 = Color(hex: p.bg500)
        bg600 = Color(hex: p.bg600)
        bg700 = Color(hex: p.bg700)

        border100 = Color(hex: p.border100)
        border200 = Color(hex: p.border200)
        border300 = Color(hex: p.border300)
        border400 = Color(hex: p.border400)
        border500 = Color(hex: p.border500)
        border600 = Color(hex: p.border600)

        btnBg000 = Color(hex: p.btnBg000)
        btnBg100 = Color(hex: p.btnBg100)
        btnBg200 = Color(hex: p.btnBg200)
        btnBg300 = Color(hex: p.btnBg300)
        btnBg400 = Color(hex: p.btnBg400)
        btnBg500 = Color(hex: p.btnBg500)
        btnBg600 = Color(hex: p.btnBg600)

        btnHeight100 = CGFloat(p.btnHeight100)
        btnHeight200 = CGFloat(p.btnHeight200)
        btnHeight300 = CGFloat(p.btnHeight300)
        btnHeight400 = CGFloat(p.btnHeight400)
        btnHeight500 = CGFloat(p.btnHeight500)
        btnHeight600 = CGFloat(p.btnHeight600)

        btnRadius000 = CGFloat(p.btnRadius000)
        btnRadius100 = CGFloat(p.btnRadius100)
        btnRadius200 = CGFloat(p.btnRadius200)
        btnRadius300 = CGFloat(p.btnRadius300)

        primary100 = Color(hex: p.primary100)
        primary200 = Color(hex: p.primary200)
        primary300 = Color(hex: p.primary300)

        success100 = Color(hex: p.success100)
        success200 = Color(hex: p.success200)
        success300 = Color(hex: p.success300)
        error100 = Color(hex: p.error100)
        error200 = Color(hex: p.error200)
        error300 = Color(hex: p.error300)

        text100 = Color(hex: p.text100)
        secondary100 = Color(hex: p.secondary100)

        inputBg100 = Color(hex: p.inputBg100)
        inputBg200 = Color(hex: p.inputBg200)
        inputBg300 = Color(hex: p.inputBg300)
        inputBorder300 = Color(hex: p.inputBorder300)
        inputHeight300 = CGFloat(p.inputHeight300)
        inputRadius300 = CGFloat(p.inputRadius300)

        radius100 = CGFloat(p.radius100)
        radius200 = CGFloat(p.radius200)
        radius300 = CGFloat(p.radius300)
        radius400 = CGFloat(p.radius400)
        radius500 = CGFloat(p.radius500)
        radius600 = CGFloat(p.radius600)

        gradientPrimary = LinearGradient(
            colors: [Color(hex: p.gradientPrimaryStart), Color(hex: p.gradientPrimaryEnd)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct AppTheme {
    fileprivate let values: AppThemeValues
    let appearance: ThemeAppearance

    init(palette: ThemePalette, appearance: ThemeAppearance) {
        self.values = AppThemeValues(palette: palette)
        self.appearance = appearance
    }

    var bg: BackgroundColors { BackgroundColors(v: values) }
    var border: BorderColors { BorderColors(v: values) }
    var button: ButtonTheme { ButtonTheme(v: values) }
    var primary: PrimaryColors { PrimaryColors(v: values) }
    var semantic: SemanticColors { SemanticColors(v: values) }
    var text: TextColors { TextColors(v: values) }
    var input: InputTheme { InputTheme(v: values) }
    var radius: RadiusValues { RadiusValues(v: values) }
    var gradientPrimary: LinearGradient { values.gradientPrimary }
    var isDark: Bool { appearance == .dark }
}

struct BackgroundColors {
    fileprivate let v: AppThemeValues
    var _000: Color { v.bg000 }
    var _100: Color { v.bg100 }
    var _200: Color { v.bg200 }
    var _300: Color { v.bg300 }
    var _400: Color { v.bg400 }
    var _500: Color { v.bg500 }
    var _600: Color { v.bg600 }
    var _700: Color { v.bg700 }
}

struct BorderColors {
    fileprivate let v: AppThemeValues
    var _100: Color { v.border100 }
    var _200: Color { v.border200 }
    var _300: Color { v.border300 }
    var _400: Color { v.border400 }
    var _500: Color { v.border500 }
    var _600: Color { v.border600 }
}

struct ButtonTheme {
    fileprivate let v: AppThemeValues
    var bg_000: Color { v.btnBg000 }
    var bg_100: Color { v.btnBg100 }
    var bg_200: Color { v.btnBg200 }
    var bg_300: Color { v.btnBg300 }
    var bg_400: Color { v.btnBg400 }
    var bg_500: Color { v.btnBg500 }
    var bg_600: Color { v.btnBg600 }
    var height_100: CGFloat { v.btnHeight100 }
    var height_200: CGFloat { v.btnHeight200 }
    var height_300: CGFloat { v.btnHeight300 }
    var height_400: CGFloat { v.btnHeight400 }
    var height_500: CGFloat { v.btnHeight500 }
    var height_600: CGFloat { v.btnHeight600 }
    var radius_000: CGFloat { v.btnRadius000 }
    var radius_100: CGFloat { v.btnRadius100 }
    var radius_200: CGFloat { v.btnRadius200 }
    var radius_300: CGFloat { v.btnRadius300 }
}

struct PrimaryColors {
    fileprivate let v: AppThemeValues
    var _100: Color { v.primary100 }
    var _200: Color { v.primary200 }
    var _300: Color { v.primary300 }
}

struct SemanticColors {
    fileprivate let v: AppThemeValues
    var success_100: Color { v.success100 }
    var success_200: Color { v.success200 }
    var success_300: Color { v.success300 }
    var error_100: Color { v.error100 }
    var error_200: Color { v.error200 }
    var error_300: Color { v.error300 }
}

struct TextColors {
    fileprivate let v: AppThemeValues
    var primary: Color { v.text100 }
    var secondary: Color { v.secondary100 }
}

struct InputTheme {
    fileprivate let v: AppThemeValues
    var bg_100: Color { v.inputBg100 }
    var bg_200: Color { v.inputBg200 }
    var bg_300: Color { v.inputBg300 }
    var border_300: Color { v.inputBorder300 }
    var height_300: CGFloat { v.inputHeight300 }
    var radius_300: CGFloat { v.inputRadius300 }
}

struct RadiusValues {
    fileprivate let v: AppThemeValues
    var _100: CGFloat { v.radius100 }
    var _200: CGFloat { v.radius200 }
    var _300: CGFloat { v.radius300 }
    var _400: CGFloat { v.radius400 }
    var _500: CGFloat { v.radius500 }
    var _600: CGFloat { v.radius600 }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6:
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8:
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, int >> 24)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
