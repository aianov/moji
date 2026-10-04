struct ThemePalette: Equatable, Sendable {
    var bg000: String
    var bg100: String
    var bg200: String
    var bg300: String
    var bg400: String
    var bg500: String
    var bg600: String
    var bg700: String
    var border100: String
    var border200: String
    var border300: String
    var border400: String
    var border500: String
    var border600: String
    var radius100: Double
    var radius200: Double
    var radius300: Double
    var radius400: Double
    var radius500: Double
    var radius600: Double
    var btnBg000: String
    var btnBg100: String
    var btnBg200: String
    var btnBg300: String
    var btnBg400: String
    var btnBg500: String
    var btnBg600: String
    var btnHeight100: Double
    var btnHeight200: Double
    var btnHeight300: Double
    var btnHeight400: Double
    var btnHeight500: Double
    var btnHeight600: Double
    var btnRadius000: Double
    var btnRadius100: Double
    var btnRadius200: Double
    var btnRadius300: Double
    var primary100: String
    var primary200: String
    var primary300: String
    var success100: String
    var success200: String
    var success300: String
    var error100: String
    var error200: String
    var error300: String
    var text100: String
    var secondary100: String
    var inputBg100: String
    var inputBg200: String
    var inputBg300: String
    var inputBorder300: String
    var inputHeight300: Double
    var inputRadius300: Double
    var gradientPrimaryStart: String
    var gradientPrimaryEnd: String

    static let defaultDark = ThemePalette(
        bg000: "#000000",
        bg100: "#020202",
        bg200: "#141414",
        bg300: "#171717",
        bg400: "#1D1D1D",
        bg500: "#232323",
        bg600: "#292929",
        bg700: "#060606",
        border100: "#252525",
        border200: "#2B2B2B",
        border300: "#313131",
        border400: "#373737",
        border500: "#3D3D3D",
        border600: "#434343",
        radius100: 20.0,
        radius200: 15.0,
        radius300: 10.0,
        radius400: 30.0,
        radius500: 40.0,
        radius600: 50.0,
        btnBg000: "#000000",
        btnBg100: "#0A0A0A",
        btnBg200: "#141414",
        btnBg300: "#1E1E1E",
        btnBg400: "#282828",
        btnBg500: "#323232",
        btnBg600: "#3C3C3C",
        btnHeight100: 55.0,
        btnHeight200: 50.0,
        btnHeight300: 45.0,
        btnHeight400: 40.0,
        btnHeight500: 35.0,
        btnHeight600: 30.0,
        btnRadius000: 10.0,
        btnRadius100: 20.0,
        btnRadius200: 30.0,
        btnRadius300: 40.0,
        primary100: "#FF5A5A",
        primary200: "#FF4848",
        primary300: "#F04545",
        success100: "#00FF00",
        success200: "#00C800",
        success300: "#009600",
        error100: "#FF1212",
        error200: "#FF0A0A",
        error300: "#FF0000",
        text100: "#FFFFFF",
        secondary100: "#C8C8C8",
        inputBg100: "#191919",
        inputBg200: "#232323",
        inputBg300: "#2D2D2D",
        inputBorder300: "#3A3A3A",
        inputHeight300: 45.0,
        inputRadius300: 10.0,
        gradientPrimaryStart: "#FF5A5A",
        gradientPrimaryEnd: "#F04545"
    )

    static let defaultLight = ThemePalette(
        bg000: "#FFFFFF",
        bg100: "#FFFFFF",
        bg200: "#F7F7F7",
        bg300: "#F2F2F7",
        bg400: "#E5E5EA",
        bg500: "#E9F0FA",
        bg600: "#EFEFF4",
        bg700: "#F8F8F8",
        border100: "#C8C7CC",
        border200: "#C8C7CC",
        border300: "#C7C7CC",
        border400: "#B2B2B2",
        border500: "#BAB9BE",
        border600: "#D6D6DC",
        radius100: 20.0,
        radius200: 15.0,
        radius300: 10.0,
        radius400: 30.0,
        radius500: 40.0,
        radius600: 50.0,
        btnBg000: "#FFFFFF",
        btnBg100: "#FFFFFF",
        btnBg200: "#F7F7F7",
        btnBg300: "#F2F2F7",
        btnBg400: "#E5E5EA",
        btnBg500: "#E9F0FA",
        btnBg600: "#E9E9EA",
        btnHeight100: 55.0,
        btnHeight200: 50.0,
        btnHeight300: 45.0,
        btnHeight400: 40.0,
        btnHeight500: 35.0,
        btnHeight600: 30.0,
        btnRadius000: 10.0,
        btnRadius100: 20.0,
        btnRadius200: 30.0,
        btnRadius300: 40.0,
        primary100: "#FF5A5A",
        primary200: "#FF4848",
        primary300: "#F04545",
        success100: "#26972C",
        success200: "#35C759",
        success300: "#00C900",
        error100: "#FF3B30",
        error200: "#FF3824",
        error300: "#CF3030",
        text100: "#000000",
        secondary100: "#8E8E93",
        inputBg100: "#F2F2F7",
        inputBg200: "#E9E9E9",
        inputBg300: "#FFFFFF",
        inputBorder300: "#C7C7CC",
        inputHeight300: 45.0,
        inputRadius300: 10.0,
        gradientPrimaryStart: "#FF5A5A",
        gradientPrimaryEnd: "#F04545"
    )
}
