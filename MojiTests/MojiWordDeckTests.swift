import Foundation
import Testing
@testable import Moji

@Suite("Words deck, furigana and search")
struct MojiWordDeckTests {
    private let deck = MojiWordTestSupport.deck
    private let kanji = MojiAlphabetCatalog.shared

    private func isHiragana(_ text: String) -> Bool {
        !text.isEmpty && text.unicodeScalars.allSatisfy { (0x3041...0x309F).contains($0.value) || $0.value == 0x30FC }
    }

    private func isKana(_ text: String) -> Bool {
        !text.isEmpty && text.unicodeScalars.allSatisfy {
            (0x3041...0x3096).contains($0.value) || (0x30A1...0x30F6).contains($0.value) || $0.value == 0x30FC
        }
    }

    @Test("The deck loads: unique ids, two languages, at least one sentence per word")
    func deckLoads() {
        #expect(deck.words.count >= 5000)
        #expect(Set(deck.words.map(\.id)).count == deck.words.count)
        for word in deck.words {
            #expect(word.id.hasPrefix("w"), "\(word.id)")
            #expect(!word.english.isEmpty && !word.russian.isEmpty, "\(word.written)")
            #expect(!word.sentences.isEmpty, "\(word.written) has no sentence")
            #expect(word.partOfSpeech != nil, "\(word.written)")
            #expect(word.romaji == MojiWordRomaji.spell(word.reading), "\(word.written)")
            for sentence in word.sentences {
                #expect(!sentence.russian.isEmpty && !sentence.english.isEmpty, "\(sentence.text)")
            }
        }
        #expect(!deck.credits.isEmpty)
    }

    @Test("Sections split the deck in frequency order")
    func sectionsInOrder() {
        #expect(!deck.sections.isEmpty)
        var previousLast = 0
        var seen: Set<String> = []
        for section in deck.sections {
            let words = deck.words(in: section)
            #expect(words.count == section.count)
            #expect(section.first == previousLast + 1, "section \(section.number)")
            #expect(section.last == section.first + section.count - 1)
            #expect(words.map(\.rank) == words.map(\.rank).sorted())
            #expect(words.allSatisfy { $0.section == section.number })
            previousLast = section.last
            for word in words {
                #expect(seen.insert(word.id).inserted)
            }
        }
        #expect(seen.count == deck.words.count)
        #expect(deck.sections.map(\.number) == deck.sections.map(\.number).sorted())
        #expect(deck.words.map(\.rank) == deck.words.map(\.rank).sorted())
        #expect(deck.words.enumerated().allSatisfy { deck.position(of: $0.element.id) == $0.offset })
    }

    @Test("Every sentence marks its word, every kanji token has a hiragana reading that fits")
    func tokens() {
        for word in deck.words {
            for sentence in word.sentences {
                let context = "\(word.written): \(sentence.text)"
                #expect(sentence.tokens.contains { $0.isTarget }, "\(context)")
                for token in sentence.tokens {
                    if token.hasKanji {
                        let reading = token.reading ?? ""
                        #expect(isHiragana(reading), "\(context): \(token.surface)")
                        #expect(MojiFurigana.aligns(surface: token.surface, reading: reading), "\(context): \(token.surface)[\(reading)]")
                    } else {
                        #expect(token.reading == nil, "\(context): \(token.surface)")
                    }
                    if !token.isPunctuation {
                        #expect(MojiWordRomaji.romaji(of: token) != nil, "\(context): \(token.surface)")
                    }
                }
                #expect(!sentence.text.contains("—") && !sentence.text.contains("–"))
                #expect(!sentence.russian.contains("—") && !sentence.russian.contains("–"), "\(context)")
                #expect(!sentence.english.contains("—") && !sentence.english.contains("–"), "\(context)")
            }
            #expect(!word.russian.contains("—") && !word.english.contains("—"), "\(word.written)")
            if word.hasKanji {
                #expect(isKana(word.reading), "\(word.written)")
                #expect(MojiFurigana.aligns(surface: word.written, reading: word.reading), "\(word.written)")
            }
        }
    }

    @Test("Furigana sits on the kanji only, split per kanji when the readings are known")
    func furigana() {
        #expect(MojiFurigana.segments(surface: "食べます", reading: "たべます") == [
            MojiRubySegment(base: "食", ruby: "た"),
            MojiRubySegment(base: "べます", ruby: nil)
        ])
        #expect(MojiFurigana.segments(surface: "お茶", reading: "おちゃ") == [
            MojiRubySegment(base: "お", ruby: nil),
            MojiRubySegment(base: "茶", ruby: "ちゃ")
        ])
        #expect(MojiFurigana.segments(surface: "飲み物", reading: "のみもの") == [
            MojiRubySegment(base: "飲", ruby: "の"),
            MojiRubySegment(base: "み", ruby: nil),
            MojiRubySegment(base: "物", ruby: "もの")
        ])
        #expect(MojiFurigana.segments(surface: "学校", reading: "がっこう", catalog: kanji) == [
            MojiRubySegment(base: "学", ruby: "がっ"),
            MojiRubySegment(base: "校", ruby: "こう")
        ])
        #expect(MojiFurigana.segments(surface: "一緒に", reading: "いっしょに", catalog: kanji) == [
            MojiRubySegment(base: "一", ruby: "いっ"),
            MojiRubySegment(base: "緒", ruby: "しょ"),
            MojiRubySegment(base: "に", ruby: nil)
        ])
        #expect(MojiFurigana.segments(surface: "今日", reading: "きょう", catalog: kanji) == [
            MojiRubySegment(base: "今日", ruby: "きょう")
        ])
        #expect(MojiFurigana.segments(surface: "パン", reading: nil) == [MojiRubySegment(base: "パン", ruby: nil)])
        #expect(MojiFurigana.segments(surface: "食べる", reading: "のむ") == [MojiRubySegment(base: "食べる", ruby: "のむ")])
        #expect(!MojiFurigana.aligns(surface: "食べる", reading: "たべた"))
    }

    @Test("Romaji for display", arguments: [
        ("がっこう", "gakkou"), ("コーヒー", "koohii"), ("きんえん", "kin'en"), ("ほんや", "hon'ya"),
        ("ちょっと", "chotto"), ("まっちゃ", "matcha"), ("パーティー", "paatii"), ("ファン", "fan"),
        ("しゅくだい", "shukudai"), ("じかん", "jikan"), ("つづく", "tsuzuku"), ("ふじさん", "fujisan")
    ])
    func romaji(kana: String, expected: String) {
        #expect(MojiWordRomaji.spell(kana) == expected)
    }

    @Test("Particles read as they sound")
    func particles() {
        #expect(MojiWordRomaji.romaji(of: MojiWordToken(surface: "は", reading: nil)) == "wa")
        #expect(MojiWordRomaji.romaji(of: MojiWordToken(surface: "へ", reading: nil)) == "e")
        #expect(MojiWordRomaji.romaji(of: MojiWordToken(surface: "を", reading: nil)) == "o")
        #expect(MojiWordRomaji.romaji(of: MojiWordToken(surface: "には", reading: nil)) == "niwa")
        #expect(MojiWordRomaji.romaji(of: MojiWordToken(surface: "歯", reading: "は")) == "ha")
        #expect(MojiWordRomaji.romaji(of: MojiWordToken(surface: "。", reading: nil)) == nil)
        #expect(MojiWordRomaji.romaji(of: MojiWordToken(surface: "日", reading: "ひ", romajiOverride: "nichi")) == "nichi")
    }

    @Test("Search finds words by kanji, kana, romaji in any spelling and meaning", arguments: [
        ("食", "w1358280"), ("たべる", "w1358280"), ("タベル", "w1358280"), ("taberu", "w1358280"),
        ("tabe", "w1358280"), ("eat", "w1358280"), ("есть", "w1358280"),
        ("gakkou", "w1206730"), ("gakko", "w1206730"), ("gakkō", "w1206730"), ("school", "w1206730"),
        ("jikan", "w1315920"), ("zikan", "w1315920"), ("koohii", "w1049180"), ("kōhī", "w1049180"),
        ("друг", "w1540170"), ("Japan", "w1582710"), ("issho", "w1163400"), ("いっしょ", "w1163400"),
        ("shigoto", "w1304970"), ("sigoto", "w1304970"), ("tsukue", "w1220210"), ("ЖДАТЬ", "w1410590"),
        ("zzqxv", nil)
    ])
    func search(query: String, expected: String?) {
        let found = deck.search.matches(query)
        if let expected {
            #expect(found.prefix(5).contains(expected), "\(query) found \(found.prefix(5))")
        } else {
            #expect(found.isEmpty, "\(query) found \(found.prefix(5))")
        }
    }

    @Test("A meaning that is the word's first sense ranks above a passing mention", arguments: [
        ("eat", "w1358280"), ("есть", "w1358280"), ("school", "w1206730"), ("wait", "w1410590")
    ])
    func primaryMeaningFirst(query: String, expected: String) {
        #expect(deck.search.matches(query).first == expected, "\(query) found \(deck.search.matches(query).prefix(5))")
    }

    @Test("Search keys treat common spellings alike")
    func searchKeys() {
        let key = MojiWordRomaji.searchKey
        #expect(key("shinbun") == key("simbun"))
        #expect(key("chotto") == key("tyotto"))
        #expect(key("matcha") == key("mattya"))
        #expect(key("tōkyō") == key("toukyou"))
        #expect(key("tsuzuku") == key("tuzuku"))
        #expect(key("jyuu") == key("zyuu") || key("ju") == key("zyu"))
        #expect(key("Fuji") == key("huzi"))
    }

    @Test("The token notation round-trips and rejects broken pieces")
    func parser() {
        let text = "*食べます[たべます]|は|日[ひ](nichi)|。"
        let tokens = MojiWordDeckParser.tokens(text)
        #expect(tokens?.count == 4)
        #expect(tokens?.first?.isTarget == true)
        #expect(tokens?.first?.reading == "たべます")
        #expect(tokens?[2].romajiOverride == "nichi")
        #expect(tokens.map(MojiWordDeckParser.format) == text)
        #expect(MojiWordDeckParser.tokens("食[]") == nil)
        #expect(MojiWordDeckParser.tokens("*") == nil)
        #expect(MojiWordDeckParser.tokens("a||b") == nil)
        #expect(MojiWordDeckParser.tokens("") == nil)
    }

    @Test("A broken word or sentence in the deck file is dropped, the rest loads")
    func lossyDeck() throws {
        let json = """
        {"version":1,"words":[
          {"id":"w1","w":"水","r":"みず","en":"water","ru":"вода","rank":2,"ex":[{"ja":"*水[みず]|。","en":"Water."},{"ja":"broken[","en":"x"}]},
          {"id":"w2","w":"","r":"","en":"","rank":1},
          {"id":"w3","w":"火","r":"ひ","en":"fire","rank":1,"sec":3,"pos":"spaceship"},
          {"nonsense":true}
        ]}
        """
        let catalog = try #require(MojiWordCatalog.decode(Data(json.utf8)))
        #expect(catalog.words.map(\.id) == ["w3", "w1"])
        #expect(catalog.word("w1")?.sentences.count == 1)
        #expect(catalog.word("w1")?.section == 1)
        #expect(catalog.word("w3")?.section == 3)
        #expect(catalog.word("w3")?.partOfSpeech == nil)
        #expect(catalog.word("w3")?.russian == "")
        #expect(catalog.word("w3")?.meaning(in: .ru) == "fire")
    }

    @Test("Card ids keep the word and the card direction")
    func cardIDs() {
        let forward = MojiWordCardID(wordID: "w1358280")
        let reverse = forward.sibling
        #expect(forward.key == "w1358280")
        #expect(reverse.key == "w1358280~r")
        #expect(MojiWordCardID(key: reverse.key) == reverse)
        #expect(MojiWordCardID(key: forward.key) == forward)
        #expect(MojiWordCardID(key: "") == nil)
    }
}
