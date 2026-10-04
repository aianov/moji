import Foundation

enum MojiWordRomaji {
    static func romaji(of token: MojiWordToken) -> String? {
        if let override = token.romajiOverride, !override.isEmpty {
            return override
        }
        guard !token.isPunctuation else { return nil }
        if token.reading == nil, let particle = particles[hiragana(token.surface)] {
            return particle
        }
        return spell(token.spoken)
    }

    static func romaji(of tokens: [MojiWordToken]) -> String {
        tokens.compactMap { romaji(of: $0) }.joined(separator: " ")
    }

    static func spell(_ kana: String) -> String? {
        let characters = Array(hiragana(kana.precomposedStringWithCanonicalMapping))
        guard !characters.isEmpty else { return nil }

        var result = ""
        var geminate = false
        var afterSyllabicN = false
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character == "っ" {
                geminate = true
                index += 1
                continue
            }
            if character == "ー" || character == "〜" {
                if let vowel = result.last(where: { vowels.contains($0) }) {
                    result.append(vowel)
                }
                afterSyllabicN = false
                index += 1
                continue
            }

            var syllable: String
            if index + 1 < characters.count, let pair = digraphs[String([character, characters[index + 1]])] {
                syllable = pair
                index += 2
            } else if let single = monographs[character] {
                syllable = single
                index += 1
            } else if let ascii = asciiForm(of: character) {
                syllable = ascii
                index += 1
            } else {
                return nil
            }

            if geminate {
                if let first = syllable.first, first.isLetter, !vowels.contains(first), first != "n" {
                    syllable = (syllable.hasPrefix("ch") ? "t" : String(first)) + syllable
                }
                geminate = false
            }
            if afterSyllabicN, let first = syllable.first, vowels.contains(first) || first == "y" {
                result.append("'")
            }
            result += syllable
            afterSyllabicN = character == "ん"
        }
        return result.isEmpty ? nil : result
    }

    static func hiragana(_ text: String) -> String {
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

    static func isKana(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            (0x3041...0x309F).contains(scalar.value) || (0x30A0...0x30FF).contains(scalar.value)
        }
    }

    static func searchKey(_ text: String) -> String {
        var letters = ""
        for character in text.precomposedStringWithCompatibilityMapping.lowercased() {
            if let plain = macronless[character] {
                letters.append(plain)
            } else if character.isASCII, character.isLetter {
                letters.append(character)
            }
        }
        var key = letters
        for (pattern, replacement) in searchRewrites {
            key = key.replacingOccurrences(of: pattern, with: replacement)
        }
        var collapsed = ""
        for character in key {
            if let last = collapsed.last, vowels.contains(character), vowels.contains(last) {
                if last == character || (last == "o" && character == "u") || (last == "e" && character == "i") {
                    continue
                }
            }
            collapsed.append(character)
        }
        return collapsed
    }

    private static func asciiForm(of character: Character) -> String? {
        let normalized = String(character).precomposedStringWithCompatibilityMapping
        guard normalized.count == 1, let first = normalized.first, first.isASCII,
              first.isLetter || first.isNumber else { return nil }
        return normalized.lowercased()
    }

    private static let vowels: Set<Character> = ["a", "i", "u", "e", "o"]

    private static let particles: [String: String] = [
        "は": "wa", "へ": "e", "を": "o",
        "には": "niwa", "では": "dewa", "とは": "towa", "へは": "ewa", "のは": "nowa",
        "からは": "karawa", "までは": "madewa", "よりは": "yoriwa", "ては": "tewa",
        "こんにちは": "konnichiwa", "こんばんは": "konbanwa"
    ]

    private static let macronless: [Character: String] = [
        "ā": "a", "ī": "i", "ū": "u", "ē": "e", "ō": "o",
        "â": "a", "î": "i", "û": "u", "ê": "e", "ô": "o"
    ]

    private static let searchRewrites: [(String, String)] = [
        ("tchi", "tti"), ("tch", "tty"), ("shi", "si"), ("sh", "sy"), ("chi", "ti"), ("ch", "ty"), ("tsu", "tu"),
        ("fu", "hu"), ("dzu", "zu"), ("du", "zu"), ("di", "zi"), ("ji", "zi"), ("j", "zy"),
        ("wo", "o"), ("nn", "n"), ("mb", "nb"), ("mp", "np"), ("mm", "nm")
    ]

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
        "わ": "wa", "ゐ": "i", "ゑ": "e", "を": "o", "ん": "n", "ゔ": "vu",
        "ぁ": "a", "ぃ": "i", "ぅ": "u", "ぇ": "e", "ぉ": "o",
        "ゃ": "ya", "ゅ": "yu", "ょ": "yo", "ゎ": "wa", "ゕ": "ka", "ゖ": "ke"
    ]

    private static let digraphs: [String: String] = {
        let stems: [(Character, String)] = [
            ("き", "ky"), ("ぎ", "gy"), ("し", "sh"), ("じ", "j"), ("ち", "ch"), ("ぢ", "j"),
            ("に", "ny"), ("ひ", "hy"), ("び", "by"), ("ぴ", "py"), ("み", "my"), ("り", "ry")
        ]
        let endings: [(Character, String)] = [("ゃ", "a"), ("ゅ", "u"), ("ょ", "o")]
        var table: [String: String] = [:]
        for (kana, consonant) in stems {
            for (small, vowel) in endings {
                table[String([kana, small])] = consonant + vowel
            }
        }
        let loanwords: [String: String] = [
            "ふぁ": "fa", "ふぃ": "fi", "ふぇ": "fe", "ふぉ": "fo", "ふゅ": "fyu",
            "てぃ": "ti", "でぃ": "di", "とぅ": "tu", "どぅ": "du", "てゅ": "tyu", "でゅ": "dyu",
            "しぇ": "she", "じぇ": "je", "ちぇ": "che", "いぇ": "ye",
            "うぃ": "wi", "うぇ": "we", "うぉ": "wo",
            "ゔぁ": "va", "ゔぃ": "vi", "ゔぇ": "ve", "ゔぉ": "vo", "ゔゅ": "vyu",
            "つぁ": "tsa", "つぃ": "tsi", "つぇ": "tse", "つぉ": "tso",
            "くぁ": "kwa", "ぐぁ": "gwa", "すぃ": "si", "ずぃ": "zi"
        ]
        table.merge(loanwords) { current, _ in current }
        return table
    }()
}
