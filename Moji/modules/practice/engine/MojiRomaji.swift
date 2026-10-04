import Foundation

enum MojiRomaji {
    static func normalize(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.precomposedStringWithCanonicalMapping.unicodeScalars {
            if (0xFF01...0xFF5E).contains(scalar.value),
               let ascii = Unicode.Scalar(scalar.value - 0xFEE0) {
                scalars.append(ascii)
            } else {
                scalars.append(scalar)
            }
        }

        var result = ""
        for character in String(scalars).lowercased() {
            if character.isWhitespace || ignored.contains(character) {
                continue
            }
            result.append(circumflexes[character] ?? character)
        }
        return result
    }

    static func spellings(of kana: String) -> Set<String>? {
        let characters = Array(hiragana(kana.precomposedStringWithCanonicalMapping))
        guard !characters.isEmpty else { return nil }

        var units: [Unit] = []
        var pendingDoubles = 0
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character == "っ" {
                pendingDoubles += 1
                index += 1
                continue
            }
            if character == "ー" {
                guard !units.isEmpty, pendingDoubles == 0 else { return nil }
                units[units.count - 1].lengthen()
                index += 1
                continue
            }

            var unit: Unit
            if index + 1 < characters.count,
               let pair = digraphs[String([character, characters[index + 1]])] {
                unit = Unit(spellings: pair)
                index += 2
            } else if let single = monographs[character] {
                unit = Unit(
                    spellings: single,
                    vowel: bareVowels[character],
                    isSyllabicN: character == "ん"
                )
                index += 1
            } else {
                return nil
            }
            for _ in 0..<pendingDoubles {
                unit.double()
            }
            pendingDoubles = 0
            units.append(unit)
        }

        for index in units.indices.dropLast() where units[index].isSyllabicN {
            let beforeLabial = units[index + 1].spellings.contains { spelling in
                spelling.first.map { labials.contains($0) } ?? false
            }
            if beforeLabial {
                units[index].spellings.append("m")
            }
        }
        return enumerate(units)
    }

    static func matches(_ typed: String, kana: String) -> Bool {
        let normalized = normalize(typed)
        guard !normalized.isEmpty else { return false }
        return spellings(of: kana)?.contains(normalized) ?? false
    }

    private struct Unit {
        var spellings: [String]
        var vowel: Character? = nil
        var isSyllabicN = false

        mutating func double() {
            spellings = spellings.flatMap { spelling -> [String] in
                guard let first = spelling.first, !MojiRomaji.vowels.contains(first) else {
                    return [spelling]
                }
                if spelling.hasPrefix("ch") {
                    return ["t" + spelling, "c" + spelling]
                }
                return [String(first) + spelling]
            }
            vowel = nil
        }

        mutating func lengthen() {
            spellings = spellings.flatMap { spelling -> [String] in
                guard let last = spelling.last, let macron = MojiRomaji.macrons[last] else {
                    return [spelling + "-"]
                }
                return [
                    spelling + String(last),
                    String(spelling.dropLast()) + String(macron),
                    spelling + "-"
                ]
            }
            vowel = nil
        }
    }

    private static func enumerate(_ units: [Unit]) -> Set<String> {
        var memo: [Int: [String]] = [:]

        func tails(from index: Int) -> [String] {
            if index == units.count {
                return [""]
            }
            if let known = memo[index] {
                return known
            }

            var result: [String] = []
            for spelling in units[index].spellings {
                for tail in tails(from: index + 1) {
                    result.append(spelling + tail)
                }
            }
            if index + 1 < units.count, let next = units[index + 1].vowel {
                for spelling in units[index].spellings {
                    guard let last = spelling.last, let long = longVowel(last, next) else { continue }
                    var heads = [String(spelling.dropLast()) + String(long)]
                    if next != last {
                        heads.append(spelling + String(last))
                    }
                    for head in heads {
                        for tail in tails(from: index + 2) {
                            result.append(head + tail)
                        }
                    }
                }
            }
            memo[index] = result
            return result
        }

        return Set(tails(from: 0))
    }

    private static func longVowel(_ last: Character, _ next: Character) -> Character? {
        switch (last, next) {
        case ("a", "a"): "ā"
        case ("i", "i"): "ī"
        case ("u", "u"): "ū"
        case ("e", "e"), ("e", "i"): "ē"
        case ("o", "o"), ("o", "u"): "ō"
        default: nil
        }
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
    private static let labials: Set<Character> = ["b", "m", "p"]
    private static let ignored: Set<Character> = ["'", "’", "‘", "ʼ", "`", "(", ")", "."]
    private static let macrons: [Character: Character] = [
        "a": "ā", "i": "ī", "u": "ū", "e": "ē", "o": "ō"
    ]
    private static let circumflexes: [Character: Character] = [
        "â": "ā", "î": "ī", "û": "ū", "ê": "ē", "ô": "ō"
    ]
    private static let bareVowels: [Character: Character] = [
        "あ": "a", "い": "i", "う": "u", "え": "e", "お": "o"
    ]

    private static let monographs: [Character: [String]] = [
        "あ": ["a"], "い": ["i"], "う": ["u"], "え": ["e"], "お": ["o"],
        "か": ["ka"], "き": ["ki"], "く": ["ku"], "け": ["ke"], "こ": ["ko"],
        "が": ["ga"], "ぎ": ["gi"], "ぐ": ["gu"], "げ": ["ge"], "ご": ["go"],
        "さ": ["sa"], "し": ["shi", "si"], "す": ["su"], "せ": ["se"], "そ": ["so"],
        "ざ": ["za"], "じ": ["ji", "zi"], "ず": ["zu"], "ぜ": ["ze"], "ぞ": ["zo"],
        "た": ["ta"], "ち": ["chi", "ti"], "つ": ["tsu", "tu"], "て": ["te"], "と": ["to"],
        "だ": ["da"], "ぢ": ["ji", "di", "zi"], "づ": ["zu", "du", "dzu"], "で": ["de"], "ど": ["do"],
        "な": ["na"], "に": ["ni"], "ぬ": ["nu"], "ね": ["ne"], "の": ["no"],
        "は": ["ha"], "ひ": ["hi"], "ふ": ["fu", "hu"], "へ": ["he"], "ほ": ["ho"],
        "ば": ["ba"], "び": ["bi"], "ぶ": ["bu"], "べ": ["be"], "ぼ": ["bo"],
        "ぱ": ["pa"], "ぴ": ["pi"], "ぷ": ["pu"], "ぺ": ["pe"], "ぽ": ["po"],
        "ま": ["ma"], "み": ["mi"], "む": ["mu"], "め": ["me"], "も": ["mo"],
        "や": ["ya"], "ゆ": ["yu"], "よ": ["yo"],
        "ら": ["ra"], "り": ["ri"], "る": ["ru"], "れ": ["re"], "ろ": ["ro"],
        "わ": ["wa"], "ゐ": ["i", "wi"], "ゑ": ["e", "we"], "を": ["o", "wo"],
        "ん": ["n", "nn"], "ゔ": ["vu"],
        "ぁ": ["xa", "la"], "ぃ": ["xi", "li"], "ぅ": ["xu", "lu"], "ぇ": ["xe", "le"], "ぉ": ["xo", "lo"],
        "ゃ": ["xya", "lya"], "ゅ": ["xyu", "lyu"], "ょ": ["xyo", "lyo"], "ゎ": ["xwa", "lwa"]
    ]

    private static let digraphs: [String: [String]] = {
        let stems: [(Character, [String])] = [
            ("き", ["ky"]), ("ぎ", ["gy"]), ("し", ["sh", "sy"]), ("じ", ["j", "jy", "zy"]),
            ("ち", ["ch", "ty", "cy"]), ("ぢ", ["j", "dy", "zy"]), ("に", ["ny"]), ("ひ", ["hy"]),
            ("び", ["by"]), ("ぴ", ["py"]), ("み", ["my"]), ("り", ["ry"])
        ]
        let endings: [(Character, String)] = [("ゃ", "a"), ("ゅ", "u"), ("ょ", "o")]

        var table: [String: [String]] = [:]
        for (kana, consonants) in stems {
            for (small, vowel) in endings {
                table[String([kana, small])] = consonants.map { $0 + vowel }
            }
        }
        let loanwords: [String: [String]] = [
            "ふぁ": ["fa"], "ふぃ": ["fi"], "ふぇ": ["fe"], "ふぉ": ["fo"], "ふゅ": ["fyu"],
            "てぃ": ["ti"], "でぃ": ["di"], "とぅ": ["tu"], "どぅ": ["du"], "でゅ": ["dyu"],
            "しぇ": ["she", "sye"], "じぇ": ["je", "jye", "zye"], "ちぇ": ["che", "tye", "cye"],
            "うぃ": ["wi"], "うぇ": ["we"], "うぉ": ["wo"], "いぇ": ["ye"],
            "ゔぁ": ["va"], "ゔぃ": ["vi"], "ゔぇ": ["ve"], "ゔぉ": ["vo"],
            "つぁ": ["tsa"], "つぃ": ["tsi"], "つぇ": ["tse"], "つぉ": ["tso"]
        ]
        table.merge(loanwords) { current, _ in current }
        return table
    }()
}
