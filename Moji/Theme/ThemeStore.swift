import Observation
import SwiftUI
import UIKit

enum ThemeAppearance: String, Sendable {
    case light
    case dark
}

enum ThemeAppearancePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }
}

private enum ThemePersistenceKey {
    static let appearancePreference = "moji.theme.appearance.v1"
}

@MainActor
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    private(set) var preference: ThemeAppearancePreference
    private(set) var resolvedAppearance: ThemeAppearance
    private(set) var currentTheme: AppTheme

    @ObservationIgnored
    private var systemAppearance: ThemeAppearance

    @ObservationIgnored
    private let darkTheme: AppTheme

    @ObservationIgnored
    private let lightTheme: AppTheme

    var preferredColorScheme: ColorScheme? {
        switch preference {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private init() {
        let darkTheme = AppTheme(palette: .defaultDark, appearance: .dark)
        let lightTheme = AppTheme(palette: .defaultLight, appearance: .light)
        let preference = UserDefaults.standard
            .string(forKey: ThemePersistenceKey.appearancePreference)
            .flatMap(ThemeAppearancePreference.init(rawValue:)) ?? .system
        let systemAppearance: ThemeAppearance = UITraitCollection.current.userInterfaceStyle == .light
            ? .light
            : .dark
        let resolved = Self.resolve(
            preference,
            systemAppearance: systemAppearance
        )

        self.darkTheme = darkTheme
        self.lightTheme = lightTheme
        self.preference = preference
        self.systemAppearance = systemAppearance
        self.resolvedAppearance = resolved
        self.currentTheme = resolved == .dark ? darkTheme : lightTheme
    }

    func setPreference(_ preference: ThemeAppearancePreference) {
        guard preference != self.preference else { return }
        self.preference = preference
        UserDefaults.standard.set(
            preference.rawValue,
            forKey: ThemePersistenceKey.appearancePreference
        )
        commit()
    }

    func reloadFromDefaults() {
        let stored = UserDefaults.standard
            .string(forKey: ThemePersistenceKey.appearancePreference)
            .flatMap(ThemeAppearancePreference.init(rawValue:)) ?? .system
        guard stored != preference else { return }
        preference = stored
        commit()
    }

    func systemColorSchemeDidChange(_ colorScheme: ColorScheme) {
        guard preference == .system else { return }
        systemAppearance = colorScheme == .light ? .light : .dark
        commit()
    }

    private func commit() {
        let next = Self.resolve(
            preference,
            systemAppearance: systemAppearance
        )
        guard next != resolvedAppearance else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            resolvedAppearance = next
            currentTheme = next == .dark ? darkTheme : lightTheme
        }
    }

    private static func resolve(
        _ preference: ThemeAppearancePreference,
        systemAppearance: ThemeAppearance
    ) -> ThemeAppearance {
        switch preference {
        case .system: systemAppearance
        case .light: .light
        case .dark: .dark
        }
    }
}
