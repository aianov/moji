import Foundation

enum MojiCellSpec: Sendable {
    case kana(_ glyph: String, _ romaji: String, id: String? = nil)
    case kanji(_ glyph: String, _ romaji: String, _ reading: String, _ meaning: String)
    case gap
}

struct MojiSectionDefinition: Sendable {
    let key: String
    let title: LocalizedStringResource?
    let subtitle: LocalizedStringResource?
    let columns: Int
    let cells: [MojiCellSpec]
}

struct MojiPageDefinition: Sendable {
    let page: MojiPage
    let idPrefix: String
    let sections: [MojiSectionDefinition]
    var lookAlikes: [[String]] = []
    var lessonOrder: String? = nil
}

enum MojiAlphabetData {
    static let pages: [MojiPageDefinition] = [hiragana, katakana] + kanjiThemes

    static let hiragana = MojiPageDefinition(
        page: .hiragana,
        idPrefix: "h",
        sections: [
            MojiSectionDefinition(
                key: "basic",
                title: nil,
                subtitle: nil,
                columns: 5,
                cells: [
                    .kana("あ", "a"), .kana("い", "i"), .kana("う", "u"), .kana("え", "e"), .kana("お", "o"),
                    .kana("か", "ka"), .kana("き", "ki"), .kana("く", "ku"), .kana("け", "ke"), .kana("こ", "ko"),
                    .kana("さ", "sa"), .kana("し", "shi"), .kana("す", "su"), .kana("せ", "se"), .kana("そ", "so"),
                    .kana("た", "ta"), .kana("ち", "chi"), .kana("つ", "tsu"), .kana("て", "te"), .kana("と", "to"),
                    .kana("な", "na"), .kana("に", "ni"), .kana("ぬ", "nu"), .kana("ね", "ne"), .kana("の", "no"),
                    .kana("は", "ha"), .kana("ひ", "hi"), .kana("ふ", "fu"), .kana("へ", "he"), .kana("ほ", "ho"),
                    .kana("ま", "ma"), .kana("み", "mi"), .kana("む", "mu"), .kana("め", "me"), .kana("も", "mo"),
                    .kana("や", "ya"), .gap, .kana("ゆ", "yu"), .gap, .kana("よ", "yo"),
                    .kana("ら", "ra"), .kana("り", "ri"), .kana("る", "ru"), .kana("れ", "re"), .kana("ろ", "ro"),
                    .kana("わ", "wa"), .gap, .gap, .gap, .kana("を", "o", id: "wo"),
                    .kana("ん", "n"), .gap, .gap, .gap, .gap
                ]
            ),
            MojiSectionDefinition(
                key: "dakuon",
                title: "Dakuon and Handakuon",
                subtitle: "Add a symbol to change the sound",
                columns: 5,
                cells: [
                    .kana("が", "ga"), .kana("ぎ", "gi"), .kana("ぐ", "gu"), .kana("げ", "ge"), .kana("ご", "go"),
                    .kana("ざ", "za"), .kana("じ", "ji"), .kana("ず", "zu"), .kana("ぜ", "ze"), .kana("ぞ", "zo"),
                    .kana("だ", "da"), .kana("ぢ", "ji", id: "di"), .kana("づ", "zu", id: "du"), .kana("で", "de"), .kana("ど", "do"),
                    .kana("ば", "ba"), .kana("び", "bi"), .kana("ぶ", "bu"), .kana("べ", "be"), .kana("ぼ", "bo"),
                    .kana("ぱ", "pa"), .kana("ぴ", "pi"), .kana("ぷ", "pu"), .kana("ぺ", "pe"), .kana("ぽ", "po")
                ]
            ),
            MojiSectionDefinition(
                key: "combo",
                title: "Combo",
                subtitle: "Add small characters to make new syllables",
                columns: 3,
                cells: [
                    .kana("きゃ", "kya"), .kana("きゅ", "kyu"), .kana("きょ", "kyo"),
                    .kana("ぎゃ", "gya"), .kana("ぎゅ", "gyu"), .kana("ぎょ", "gyo"),
                    .kana("しゃ", "sha"), .kana("しゅ", "shu"), .kana("しょ", "sho"),
                    .kana("じゃ", "ja"), .kana("じゅ", "ju"), .kana("じょ", "jo"),
                    .kana("ちゃ", "cha"), .kana("ちゅ", "chu"), .kana("ちょ", "cho"),
                    .kana("にゃ", "nya"), .kana("にゅ", "nyu"), .kana("にょ", "nyo"),
                    .kana("ひゃ", "hya"), .kana("ひゅ", "hyu"), .kana("ひょ", "hyo"),
                    .kana("びゃ", "bya"), .kana("びゅ", "byu"), .kana("びょ", "byo"),
                    .kana("ぴゃ", "pya"), .kana("ぴゅ", "pyu"), .kana("ぴょ", "pyo"),
                    .kana("みゃ", "mya"), .kana("みゅ", "myu"), .kana("みょ", "myo"),
                    .kana("りゃ", "rya"), .kana("りゅ", "ryu"), .kana("りょ", "ryo")
                ]
            ),
            MojiSectionDefinition(
                key: "small-tsu",
                title: "Small っ",
                subtitle: "Double the following consonant",
                columns: 4,
                cells: [
                    .kana("っか", "kka"), .kana("っさ", "ssa"), .kana("った", "tta"), .kana("っぱ", "ppa")
                ]
            ),
            MojiSectionDefinition(
                key: "long-vowels",
                title: "Long vowels",
                subtitle: "Hold the vowel for an extra beat",
                columns: 5,
                cells: [
                    .kana("ああ", "aa"), .kana("いい", "ii"), .kana("うう", "uu"), .kana("ええ", "ee"), .kana("おお", "oo"),
                    .gap, .gap, .gap, .kana("えい", "ei"), .kana("おう", "ou")
                ]
            )
        ],
        lookAlikes: [
            ["あ", "お", "め", "ぬ"], ["ぬ", "め", "ね"], ["ね", "れ", "わ"], ["る", "ろ"],
            ["さ", "ち", "き"], ["ち", "ら"], ["は", "ほ", "ま"], ["ま", "も", "よ"],
            ["い", "り", "こ"], ["こ", "に", "た"], ["た", "な"], ["う", "ら", "つ"],
            ["し", "つ", "て"], ["く", "へ"], ["け", "は"], ["そ", "て", "ろ"], ["ゆ", "よ"],
            ["ん", "そ"], ["お", "む", "を"], ["か", "が"], ["き", "ぎ"],
            ["は", "ば", "ぱ"], ["ひ", "び", "ぴ"], ["ふ", "ぶ", "ぷ"], ["へ", "べ", "ぺ"], ["ほ", "ぼ", "ぽ"],
            ["っか", "か"], ["っさ", "さ"], ["った", "た"], ["っぱ", "ぱ"],
            ["ああ", "あ"], ["いい", "い"], ["うう", "う"], ["ええ", "えい", "え"], ["おお", "おう", "お"],
            ["きゃ", "きょ", "ぎゃ"], ["しゃ", "じゃ", "ちゃ"], ["しゅ", "じゅ", "ちゅ"], ["しょ", "じょ", "ちょ"]
        ]
    )

    static let katakana = MojiPageDefinition(
        page: .katakana,
        idPrefix: "k",
        sections: [
            MojiSectionDefinition(
                key: "basic",
                title: nil,
                subtitle: nil,
                columns: 5,
                cells: [
                    .kana("ア", "a"), .kana("イ", "i"), .kana("ウ", "u"), .kana("エ", "e"), .kana("オ", "o"),
                    .kana("カ", "ka"), .kana("キ", "ki"), .kana("ク", "ku"), .kana("ケ", "ke"), .kana("コ", "ko"),
                    .kana("サ", "sa"), .kana("シ", "shi"), .kana("ス", "su"), .kana("セ", "se"), .kana("ソ", "so"),
                    .kana("タ", "ta"), .kana("チ", "chi"), .kana("ツ", "tsu"), .kana("テ", "te"), .kana("ト", "to"),
                    .kana("ナ", "na"), .kana("ニ", "ni"), .kana("ヌ", "nu"), .kana("ネ", "ne"), .kana("ノ", "no"),
                    .kana("ハ", "ha"), .kana("ヒ", "hi"), .kana("フ", "fu"), .kana("ヘ", "he"), .kana("ホ", "ho"),
                    .kana("マ", "ma"), .kana("ミ", "mi"), .kana("ム", "mu"), .kana("メ", "me"), .kana("モ", "mo"),
                    .kana("ヤ", "ya"), .gap, .kana("ユ", "yu"), .gap, .kana("ヨ", "yo"),
                    .kana("ラ", "ra"), .kana("リ", "ri"), .kana("ル", "ru"), .kana("レ", "re"), .kana("ロ", "ro"),
                    .kana("ワ", "wa"), .gap, .gap, .gap, .kana("ヲ", "wo"),
                    .kana("ン", "n"), .gap, .gap, .gap, .gap
                ]
            ),
            MojiSectionDefinition(
                key: "dakuon",
                title: "Dakuon and Handakuon",
                subtitle: "Add a symbol to change the sound",
                columns: 5,
                cells: [
                    .kana("ガ", "ga"), .kana("ギ", "gi"), .kana("グ", "gu"), .kana("ゲ", "ge"), .kana("ゴ", "go"),
                    .kana("ザ", "za"), .kana("ジ", "ji"), .kana("ズ", "zu"), .kana("ゼ", "ze"), .kana("ゾ", "zo"),
                    .kana("ダ", "da"), .kana("ヂ", "ji", id: "di"), .kana("ヅ", "zu", id: "du"), .kana("デ", "de"), .kana("ド", "do"),
                    .kana("バ", "ba"), .kana("ビ", "bi"), .kana("ブ", "bu"), .kana("ベ", "be"), .kana("ボ", "bo"),
                    .kana("パ", "pa"), .kana("ピ", "pi"), .kana("プ", "pu"), .kana("ペ", "pe"), .kana("ポ", "po")
                ]
            ),
            MojiSectionDefinition(
                key: "combo",
                title: "Combo",
                subtitle: "Add small characters to make new syllables",
                columns: 3,
                cells: [
                    .kana("キャ", "kya"), .kana("キュ", "kyu"), .kana("キョ", "kyo"),
                    .kana("ギャ", "gya"), .kana("ギュ", "gyu"), .kana("ギョ", "gyo"),
                    .kana("シャ", "sha"), .kana("シュ", "shu"), .kana("ショ", "sho"),
                    .kana("ジャ", "ja"), .kana("ジュ", "ju"), .kana("ジョ", "jo"),
                    .kana("チャ", "cha"), .kana("チュ", "chu"), .kana("チョ", "cho"),
                    .kana("ニャ", "nya"), .kana("ニュ", "nyu"), .kana("ニョ", "nyo"),
                    .kana("ヒャ", "hya"), .kana("ヒュ", "hyu"), .kana("ヒョ", "hyo"),
                    .kana("ビャ", "bya"), .kana("ビュ", "byu"), .kana("ビョ", "byo"),
                    .kana("ピャ", "pya"), .kana("ピュ", "pyu"), .kana("ピョ", "pyo"),
                    .kana("ミャ", "mya"), .kana("ミュ", "myu"), .kana("ミョ", "myo"),
                    .kana("リャ", "rya"), .kana("リュ", "ryu"), .kana("リョ", "ryo")
                ]
            ),
            MojiSectionDefinition(
                key: "small-tsu",
                title: "Small ッ",
                subtitle: "Double the following consonant",
                columns: 4,
                cells: [
                    .kana("ッカ", "kka"), .kana("ッサ", "ssa"), .kana("ッタ", "tta"), .kana("ッパ", "ppa")
                ]
            ),
            MojiSectionDefinition(
                key: "long-vowels",
                title: "Long vowels",
                subtitle: "The bar ー holds the vowel for an extra beat",
                columns: 5,
                cells: [
                    .kana("アー", "aa"), .kana("イー", "ii"), .kana("ウー", "uu"), .kana("エー", "ee"), .kana("オー", "oo")
                ]
            )
        ],
        lookAlikes: [
            ["シ", "ツ", "ミ"], ["ツ", "ソ"], ["ソ", "ン", "リ"], ["ン", "シ"],
            ["ク", "ケ", "タ", "ワ"], ["ワ", "ウ", "フ"], ["フ", "ヌ", "ラ"], ["ヌ", "ス", "メ"], ["ス", "ヲ"],
            ["チ", "テ", "ナ"], ["ユ", "コ", "ヨ"], ["コ", "ロ"], ["ア", "マ", "ヤ"], ["マ", "ム"],
            ["ナ", "メ", "ノ"], ["ル", "レ"], ["セ", "サ", "ヒ"], ["ヨ", "ヲ"], ["エ", "ニ", "ユ"], ["ニ", "ミ"],
            ["カ", "ガ"], ["キ", "ギ"],
            ["ハ", "バ", "パ"], ["ヒ", "ビ", "ピ"], ["フ", "ブ", "プ"], ["ヘ", "ベ", "ペ"], ["ホ", "ボ", "ポ"],
            ["ッカ", "カ"], ["ッサ", "サ"], ["ッタ", "タ"], ["ッパ", "パ"],
            ["アー", "ア"], ["イー", "イ"], ["ウー", "ウ"], ["エー", "エ"], ["オー", "オ"],
            ["キャ", "キョ", "ギャ"], ["シャ", "ジャ", "チャ"], ["シュ", "ジュ", "チュ"], ["ショ", "ジョ", "チョ"]
        ]
    )
}
