import Foundation
import Observation

private enum MojiPreferenceKey {
    static let speaksCharacters = "moji.preferences.speaks_characters.v1"
}

@MainActor
@Observable
final class MojiPreferencesStore {
    static let shared = MojiPreferencesStore()

    private(set) var speaksCharacters: Bool

    private init() {
        let defaults = UserDefaults.standard
        speaksCharacters = defaults.object(forKey: MojiPreferenceKey.speaksCharacters) as? Bool ?? true
    }

    func setSpeaksCharacters(_ value: Bool) {
        guard value != speaksCharacters else { return }
        speaksCharacters = value
        UserDefaults.standard.set(value, forKey: MojiPreferenceKey.speaksCharacters)
    }
}
