import Foundation
import Testing
@testable import Moji

@Suite("Readings for my cards")
struct MojiWordReadingsTests {
    private var dictionary: MojiWordReadingDictionary {
        MojiWordReadingDictionary(catalog: MojiWordTestSupport.deck)
    }

    private func spelled(_ tokens: [MojiWordToken]) -> String {
        tokens.map { token in
            let mark = token.isTarget ? "*" : ""
            guard let reading = token.reading else { return mark + token.surface }
            return mark + "\(token.surface)[\(reading)]"
        }
        .joined(separator: "|")
    }

    @Test("The tokenizer reads common words in hiragana", arguments: [
        ("食べる", "たべる"),
        ("東京", "とうきょう"),
        ("学校", "がっこう"),
        ("禁煙", "きんえん"),
        ("今日", "きょう"),
        ("勉強する", "べんきょうする"),
        ("新しい", "あたらしい"),
        ("可愛い", "かわいい"),
        (" 飲む ", "のむ")
    ])
    func tokenizerReadings(word: String, reading: String) {
        #expect(MojiWordReadings.reading(of: word) == reading)
    }

    @Test("Kana words keep their own spelling, turned into hiragana")
    func kanaWords() {
        #expect(MojiWordReadings.reading(of: "ちょっと") == "ちょっと")
        #expect(MojiWordReadings.reading(of: "コーヒー") == "こーひー")
        #expect(MojiWordReadings.reading(of: "") == "")
    }

    @Test("Words the deck knows take the deck's reading over the tokenizer's", arguments: [
        ("日本語", "にほんご"),
        ("お母さん", "おかあさん"),
        ("私", "わたし"),
        ("明日", "あした")
    ])
    func deckReadings(word: String, reading: String) throws {
        try #require(!MojiWordTestSupport.deck.isEmpty)
        #expect(MojiWordReadings.reading(of: word, dictionary: dictionary) == reading)
    }

    @Test("A sentence splits into words with furigana over the kanji only")
    func sentenceTokens() {
        let tokens = MojiWordReadings.tokens(of: "今日は東京へ行きます。")
        #expect(tokens.map(\.surface).joined() == "今日は東京へ行きます。")
        #expect(spelled(tokens) == "今日[きょう]|は|東京[とうきょう]|へ|行き[いき]|ます|。")
        #expect(MojiWordReadings.tokens(of: "").isEmpty)
    }

    @Test("Deck words glue split pieces back together in a sentence")
    func sentenceCompounds() throws {
        try #require(!MojiWordTestSupport.deck.isEmpty)
        let tokens = MojiWordReadings.tokens(of: "お母さんは日本語を勉強しています", dictionary: dictionary)
        #expect(tokens.first == MojiWordToken(surface: "お母さん", reading: "おかあさん"))
        #expect(tokens.contains(MojiWordToken(surface: "日本語", reading: "にほんご")))
        let counted = MojiWordReadings.tokens(of: "3人で行った", dictionary: dictionary)
        #expect(counted.contains(MojiWordToken(surface: "人", reading: "にん")))
    }

    @Test("A fixed reading replaces the found one wherever that word appears")
    func fixes() {
        let tokens = MojiWordReadings.tokens(of: "私は私です", fixes: ["私": "わたし", "は": "ignored"])
        #expect(spelled(tokens) == "私[わたし]|は|私[わたし]|です")
        let empty = MojiWordReadings.tokens(of: "私です", fixes: ["私": ""])
        #expect(empty == MojiWordReadings.tokens(of: "私です"))
        #expect(empty.first?.reading?.isEmpty == false)
    }

    @Test("The card's word is marked in its sentence, even when it is conjugated")
    func target() {
        let eat = MojiWordReadings.markingTarget(MojiWordReadings.tokens(of: "毎朝パンを食べます"), word: "食べる")
        #expect(eat.filter(\.isTarget).map(\.surface) == ["食べ"])
        let go = MojiWordReadings.markingTarget(MojiWordReadings.tokens(of: "学校へ行きました"), word: "行く")
        #expect(go.filter(\.isTarget).map(\.surface) == ["行き"])
        let kana = MojiWordReadings.markingTarget(MojiWordReadings.tokens(of: "ちょっと待って"), word: "ちょっと")
        #expect(kana.filter(\.isTarget).map(\.surface) == ["ちょっと"])
        let absent = MojiWordReadings.markingTarget(eat, word: "猫")
        #expect(absent.allSatisfy { !$0.isTarget })
    }

    @Test("Typed readings become hiragana: romaji, katakana and spaces", arguments: [
        ("taberu", "たべる"),
        ("TABERU", "たべる"),
        ("た べ る", "たべる"),
        ("タベル", "たべる"),
        ("kin'en", "きんえん"),
        ("gakkou", "がっこう"),
        ("shinbun", "しんぶん"),
        ("", "")
    ])
    func normalizedReadings(typed: String, reading: String) {
        #expect(MojiWordReadings.normalized(typed) == reading)
    }

    @Test("Romaji of a card follows its reading")
    func romaji() {
        let word = MojiOwnWord(input: MojiOwnWordInput(written: "食べる", reading: "たべる", meaning: "eat"), at: Date())
        #expect(word.romaji == "taberu")
        #expect(word.word(rank: 1).romaji == "taberu")
        let kana = MojiOwnWord(input: MojiOwnWordInput(written: "コーヒー", reading: "", meaning: "coffee"), at: Date())
        #expect(kana.romaji == "koohii")
    }
}
