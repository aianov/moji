import Foundation

enum MojiHepburn {
    static func spell(_ kana: String) -> String? {
        let characters = Array(hiragana(kana.precomposedStringWithCanonicalMapping))
        guard !characters.isEmpty else { return nil }

        var result = ""
        var doubles = false
        var index = 0
        while index < characters.count {
            let character = characters[index]
            switch character {
            case "(", ")":
                result.append(character)
                index += 1
                continue
            case "っ":
                doubles = true
                index += 1
                continue
            case "ー":
                guard let last = result.last, vowels.contains(last) else { return nil }
                result.append(last)
                index += 1
                continue
            default:
                break
            }

            guard var syllable = monographs[character] else { return nil }
            index += 1
            if index < characters.count,
               let small = smallY[characters[index]],
               syllable.count > 1,
               syllable.hasSuffix("i") {
                let stem = String(syllable.dropLast())
                syllable = ["sh", "ch", "j"].contains(stem) ? stem + small : stem + "y" + small
                index += 1
            }
            if doubles {
                guard let first = syllable.first, !vowels.contains(first) else { return nil }
                syllable = (syllable.hasPrefix("ch") ? "t" : String(first)) + syllable
                doubles = false
            }
            result += syllable
        }
        return doubles ? nil : result
    }

    private static func hiragana(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if (0x30A1...0x30F6).contains(scalar.value),
               let converted = Unicode.Scalar(scalar.value - 0x60) {
                scalars.append(converted)
            } else {
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    private static let vowels: Set<Character> = ["a", "i", "u", "e", "o"]

    private static let smallY: [Character: String] = ["ゃ": "a", "ゅ": "u", "ょ": "o"]

    private static let monographs: [Character: String] = [
        "あ": "a", "い": "i", "う": "u", "え": "e", "お": "o",
        "か": "ka", "き": "ki", "く": "ku", "け": "ke", "こ": "ko",
        "が": "ga", "ぎ": "gi", "ぐ": "gu", "げ": "ge", "ご": "go",
        "さ": "sa", "し": "shi", "す": "su", "せ": "se", "そ": "so",
        "ざ": "za", "じ": "ji", "ず": "zu", "ぜ": "ze", "ぞ": "zo",
        "た": "ta", "ち": "chi", "つ": "tsu", "て": "te", "と": "to",
        "だ": "da", "ぢ": "ji", "づ": "zu", "で": "de", "ど": "do",
        "な": "na", "に": "ni", "ぬ": "nu", "ね": "ne", "の": "no",
        "は": "ha", "ひ": "hi", "ふ": "fu", "へ": "he", "ほ": "ho",
        "ば": "ba", "び": "bi", "ぶ": "bu", "べ": "be", "ぼ": "bo",
        "ぱ": "pa", "ぴ": "pi", "ぷ": "pu", "ぺ": "pe", "ぽ": "po",
        "ま": "ma", "み": "mi", "む": "mu", "め": "me", "も": "mo",
        "や": "ya", "ゆ": "yu", "よ": "yo",
        "ら": "ra", "り": "ri", "る": "ru", "れ": "re", "ろ": "ro",
        "わ": "wa", "を": "o", "ん": "n"
    ]
}
