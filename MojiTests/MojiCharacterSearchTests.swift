import Foundation
import Testing
@testable import Moji

@Suite("Character search")
struct MojiCharacterSearchTests {
    private let catalog = MojiAlphabetCatalog.shared

    private func glyphs(_ query: String, on script: MojiScript) -> [String] {
        MojiCharacterSearch(characters: catalog.characters(script))
            .matches(query)
            .compactMap { catalog.character($0)?.glyph }
    }

    private func ordered(_ query: String, from page: MojiPage) -> [String] {
        let found = Set(MojiCharacterSearch(characters: catalog.characters(page.script)).matches(query))
        return catalog.searchPages(page.script, from: page)
            .flatMap { catalog.pool($0).map(\.id) }
            .filter(found.contains)
    }

    @Test("A typed glyph finds exactly that character")
    func glyph() {
        #expect(glyphs("し", on: .hiragana) == ["し"])
        #expect(glyphs("じ", on: .hiragana) == ["じ"])
        #expect(glyphs("きゃ", on: .hiragana) == ["きゃ"])
        #expect(glyphs("シ", on: .katakana) == ["シ"])
        #expect(glyphs("日", on: .kanji) == ["日"])
        #expect(glyphs(" 日 ", on: .kanji) == ["日"])
        #expect(glyphs("日", on: .hiragana).isEmpty)
    }

    @Test("Kana from the other kana keyboard finds its twin")
    func kanaTwin() {
        #expect(glyphs("し", on: .katakana) == ["シ"])
        #expect(glyphs("ヲ", on: .hiragana) == ["を"])
    }

    @Test("Romaji finds kana in any common spelling", arguments: [
        ("shi", "し"), ("si", "し"), ("SHI", "し"), (" s h i ", "し"),
        ("tsu", "つ"), ("tu", "つ"), ("fu", "ふ"), ("hu", "ふ"),
        ("sha", "しゃ"), ("sya", "しゃ"), ("kka", "っか"), ("aa", "ああ")
    ])
    func romaji(typed: String, glyph: String) {
        #expect(glyphs(typed, on: .hiragana) == [glyph])
    }

    @Test("Romaji shared by two kana finds both, in page order")
    func sharedRomaji() {
        #expect(glyphs("o", on: .hiragana) == ["お", "を"])
        #expect(glyphs("ji", on: .hiragana) == ["じ", "ぢ"])
        #expect(glyphs("wo", on: .hiragana) == ["を"])
        #expect(glyphs("shi", on: .katakana) == ["シ"])
    }

    @Test("Kanji are found by any of their readings")
    func kanjiReadings() {
        for typed in ["hi", "nichi", "NICHI", "jitsu", "にち"] {
            #expect(glyphs(typed, on: .kanji).contains("日"), "\(typed)")
        }
        #expect(glyphs("hitotsu", on: .kanji).contains("一"))
        #expect(!glyphs("nichi", on: .kanji).contains("月"))
    }

    @Test("Only whole romaji counts")
    func wholeRomajiOnly() {
        #expect(glyphs("k", on: .hiragana).isEmpty)
        #expect(glyphs("sh", on: .hiragana).isEmpty)
        #expect(glyphs("ka", on: .hiragana) == ["か"])
        #expect(glyphs("a", on: .hiragana) == ["あ"])
        #expect(glyphs("nic", on: .kanji).isEmpty)
        #expect(glyphs("", on: .hiragana).isEmpty)
        #expect(glyphs("   ", on: .hiragana).isEmpty)
    }

    @Test("A found character scrolls to the chart row it sits in")
    func chartRows() throws {
        let basic = try #require(catalog.sections(.hiragana).first)
        let rows = basic.rows
        #expect(rows.count == 11)
        #expect(rows.allSatisfy { $0.slots.count == basic.columns })
        #expect(Set(rows.map(\.id)).count == rows.count)

        let last = try #require(rows.last)
        #expect(last.slots.first?.id == "h-n")
        #expect(basic.rowID(containing: "h-n") == last.id)
        #expect(basic.rowID(containing: "h-a") == rows.first?.id)
        #expect(basic.rowID(containing: "h-ga") == nil)
    }

    @Test("A kanji from another theme is found and names its own theme", arguments: MojiKanjiTheme.allCases)
    func kanjiFromAnotherTheme(theme: MojiKanjiTheme) throws {
        let day = try #require(catalog.character("j-日"))
        let found = ordered("日", from: .kanji(theme))
        #expect(found == [day.id])
        #expect(catalog.character(try #require(found.first))?.page == day.page)
    }

    @Test("Kanji search starts in the current theme, then the next ones, then wraps", arguments: MojiKanjiTheme.allCases)
    func searchRunsThroughTheThemes(theme: MojiKanjiTheme) throws {
        let all = catalog.pages(.kanji)
        let start = try #require(all.firstIndex(of: .kanji(theme)))
        let rotation = catalog.searchPages(.kanji, from: .kanji(theme))
        #expect(rotation == Array(all[start...] + all[..<start]))

        let pages = ordered("kou", from: .kanji(theme)).compactMap { catalog.character($0)?.page }
        #expect(Set(pages).count > 3)
        let ranks = pages.compactMap { rotation.firstIndex(of: $0) }
        #expect(ranks.count == pages.count)
        #expect(ranks == ranks.sorted())
        if pages.contains(.kanji(theme)) {
            #expect(pages.first == .kanji(theme))
        }
    }

    @Test("Inside a theme, matches come in lesson order")
    func matchesFollowTheLessonOrder() throws {
        let found = ordered("kou", from: .kanji(.people))
        for page in catalog.pages(.kanji) {
            let inPage = found.filter { catalog.character($0)?.page == page }
            let lessonOrder = catalog.pool(page).map(\.id).filter(inPage.contains)
            #expect(inPage == lessonOrder, "\(page.rawValue)")
        }
    }

    @Test("Kana search stays on its own page")
    func kanaSearchStaysHome() {
        #expect(catalog.searchPages(.hiragana, from: .hiragana) == [.hiragana])
        #expect(catalog.searchPages(.katakana, from: .katakana) == [.katakana])
        #expect(ordered("shi", from: .hiragana) == ["h-shi"])
        #expect(ordered("日", from: .katakana).isEmpty)
    }
}
