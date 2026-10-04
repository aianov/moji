import Foundation

enum MojiScript: String, CaseIterable, Identifiable, Sendable {
    case hiragana
    case katakana
    case kanji

    var id: String { rawValue }

    init?(storedValue: String) {
        if let script = MojiScript(rawValue: storedValue) {
            self = script
        } else if storedValue == MojiPage.legacyKanjiPlusKey {
            self = .kanji
        } else {
            return nil
        }
    }

    var title: String {
        switch self {
        case .hiragana: String(localized: "Hiragana")
        case .katakana: String(localized: "Katakana")
        case .kanji: String(localized: "Kanji")
        }
    }

    var symbol: String {
        switch self {
        case .hiragana: "あ"
        case .katakana: "ア"
        case .kanji: "字"
        }
    }

    var isKanji: Bool {
        self == .kanji
    }

    func countText(_ count: Int) -> String {
        isKanji
            ? String(localized: "\(count) kanji")
            : String(localized: "\(count) characters")
    }
}

enum MojiPage: Hashable, Identifiable, Sendable {
    case hiragana
    case katakana
    case kanji(MojiKanjiTheme)

    static let legacyKanjiKey = "kanji"
    static let legacyKanjiPlusKey = "kanji_plus"
    static let legacyKanjiKeys = [legacyKanjiKey, legacyKanjiPlusKey]

    static let all: [MojiPage] = [.hiragana, .katakana] + MojiKanjiTheme.allCases.map { .kanji($0) }

    private static let kanjiPrefix = "kanji."

    init(script: MojiScript, theme: MojiKanjiTheme) {
        switch script {
        case .hiragana: self = .hiragana
        case .katakana: self = .katakana
        case .kanji: self = .kanji(theme)
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "hiragana":
            self = .hiragana
        case "katakana":
            self = .katakana
        default:
            guard rawValue.hasPrefix(Self.kanjiPrefix),
                  let theme = MojiKanjiTheme(rawValue: String(rawValue.dropFirst(Self.kanjiPrefix.count))) else {
                return nil
            }
            self = .kanji(theme)
        }
    }

    var rawValue: String {
        switch self {
        case .hiragana: "hiragana"
        case .katakana: "katakana"
        case .kanji(let theme): Self.kanjiPrefix + theme.rawValue
        }
    }

    var id: String { rawValue }

    var script: MojiScript {
        switch self {
        case .hiragana: .hiragana
        case .katakana: .katakana
        case .kanji: .kanji
        }
    }

    var theme: MojiKanjiTheme? {
        guard case .kanji(let theme) = self else { return nil }
        return theme
    }

    var isKanji: Bool {
        script.isKanji
    }

    var title: String {
        theme?.title ?? script.title
    }

    var fullTitle: String {
        guard let theme else { return script.title }
        return String(localized: "Kanji · \(theme.title)")
    }

    var symbol: String {
        theme?.symbol ?? script.symbol
    }
}

extension MojiPage: Codable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let page = MojiPage(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown page \(rawValue)")
        }
        self = page
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct MojiReading: Hashable, Sendable {
    let kana: String
    let romaji: String

    var line: String {
        "\(kana) · \(romaji)"
    }
}

struct MojiCharacter: Identifiable, Hashable, Sendable {
    let id: String
    let script: MojiScript
    let page: MojiPage
    let sectionID: String
    let glyph: String
    let romaji: String
    let reading: String?
    let meaning: String?
    var otherReadings: [MojiReading] = []

    var speech: String {
        guard let reading else { return glyph }
        return reading
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
    }

    var shortMeaning: String? {
        guard let meaning else { return nil }
        var depth = 0
        var end = meaning.endIndex
        for index in meaning.indices {
            switch meaning[index] {
            case "(": depth += 1
            case ")": depth = max(0, depth - 1)
            case "," where depth == 0: end = index
            default: continue
            }
            if end != meaning.endIndex { break }
        }
        let first = meaning[..<end]
        guard let open = first.firstIndex(of: "("),
              first[open...].unicodeScalars.contains(where: Self.isJapanese) else {
            return first.trimmingCharacters(in: .whitespaces)
        }
        return first[..<open].trimmingCharacters(in: .whitespaces)
    }

    private static func isJapanese(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF: true
        default: false
        }
    }

    var readingLine: String {
        guard let reading else { return romaji }
        return "\(reading) · \(romaji)"
    }

    var otherReadingsLine: String? {
        guard !otherReadings.isEmpty else { return nil }
        return otherReadings.map(\.line).joined(separator: ", ")
    }

    var optionKey: String {
        meaning ?? romaji
    }
}

struct MojiCharacterSection: Identifiable, Sendable {
    let id: String
    let page: MojiPage
    let title: String?
    let subtitle: String?
    let columns: Int
    let slots: [MojiCharacterSlot]
}

enum MojiCharacterSlot: Identifiable, Sendable {
    case character(MojiCharacter)
    case gap(String)

    var id: String {
        switch self {
        case .character(let character): character.id
        case .gap(let id): id
        }
    }
}
