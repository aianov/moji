import Foundation

enum MojiVoiceLibrary {
    static let fileExtension = "m4a"

    static let credit = "NHK WORLD-JAPAN, JapanesePod101"

    static func resourceName(for characterID: String) -> String {
        var name = "voice-"
        for scalar in characterID.unicodeScalars {
            if scalar.isASCII, scalar == "-" || CharacterSet.alphanumerics.contains(scalar) {
                name.unicodeScalars.append(scalar)
            } else {
                name += "u" + String(scalar.value, radix: 16, uppercase: true)
            }
        }
        return name
    }

    static func url(for character: MojiCharacter, in bundle: Bundle = .main) -> URL? {
        bundle.url(
            forResource: resourceName(for: character.id),
            withExtension: fileExtension
        )
    }
}
