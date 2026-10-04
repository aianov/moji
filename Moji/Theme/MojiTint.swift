import SwiftUI

enum MojiTint {
    static let gold = Color(hex: "#D9A441")
    static let flame = Color(hex: "#F08A24")
    static let correct = Color(hex: "#2F9E55")
    static let wrong = Color(hex: "#C9473F")
    static let highlight = Color(hex: "#FFCC00")

    static func contribution(level: Int, appearance: ThemeAppearance) -> Color {
        switch appearance {
        case .dark:
            switch level {
            case ..<1: Color(hex: "#1D1D1D")
            case 1: Color(hex: "#006D32")
            case 2: Color(hex: "#26A641")
            default: Color(hex: "#39D353")
            }
        case .light:
            switch level {
            case ..<1: Color(hex: "#EBEDF0")
            case 1: Color(hex: "#40C463")
            case 2: Color(hex: "#30A14E")
            default: Color(hex: "#216E39")
            }
        }
    }
}
