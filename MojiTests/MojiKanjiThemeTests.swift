import Foundation
import Testing
@testable import Moji

@Suite("Kanji themes")
struct MojiKanjiThemeTests {
    private let catalog = MojiAlphabetCatalog.shared
    private let planner = MojiLearnPlanner.shared

    @Test("The pages are the two kana and one page per kanji theme, in theme order")
    func pages() {
        #expect(catalog.pages == MojiPage.all)
        #expect(catalog.pages(.kanji) == MojiKanjiTheme.allCases.map { MojiPage.kanji($0) })
        #expect(catalog.pages(.hiragana) == [.hiragana])
        #expect(catalog.pages(.katakana) == [.katakana])
        #expect(MojiAlphabetData.kanjiThemes.map(\.page) == catalog.pages(.kanji))
    }

    @Test("Every kanji sits in exactly one theme and keeps its id")
    func everyKanjiInOneTheme() {
        let ids = catalog.pages(.kanji).flatMap { catalog.pool($0).map(\.id) }
        #expect(ids.count == 2_942)
        #expect(Set(ids).count == ids.count)
        #expect(Set(ids) == Set(catalog.characters(.kanji).map(\.id)))

        for character in catalog.characters(.kanji) {
            #expect(character.id == "j-\(character.glyph)")
            #expect(character.script == .kanji)
            #expect(character.page.isKanji)
            #expect(character.sectionID.hasPrefix(character.page.rawValue + "."))
            #expect(catalog.pool(character.page).contains { $0.id == character.id }, "\(character.glyph)")
        }
    }

    @Test("Every theme holds 60 to 200 kanji", arguments: MojiKanjiTheme.allCases)
    func themeSize(theme: MojiKanjiTheme) {
        let count = catalog.pool(.kanji(theme)).count
        #expect((60...200).contains(count), "\(theme.rawValue): \(count)")
        #expect(catalog.chart(.kanji(theme)).count == count)
    }

    @Test("Lessons follow the theme's order and every section keeps it", arguments: MojiKanjiTheme.allCases)
    func lessonOrder(theme: MojiKanjiTheme) throws {
        let page = MojiPage.kanji(theme)
        let definition = try #require(MojiAlphabetData.kanjiThemes.first { $0.page == page })
        let order = try #require(definition.lessonOrder).map(String.init)
        let pool = catalog.pool(page)
        #expect(pool.map(\.glyph) == order)

        let position = Dictionary(uniqueKeysWithValues: pool.enumerated().map { ($0.element.id, $0.offset) })
        let sections = catalog.sections(page)
        #expect(sections.count == definition.sections.count)
        #expect(sections.count >= 2)
        var heads: [Int] = []
        for section in sections {
            let ranks = catalog.members(ofSection: section.id).compactMap { position[$0.id] }
            #expect(!ranks.isEmpty, "\(section.id)")
            #expect(ranks == ranks.sorted(), "\(section.id)")
            heads.append(ranks.first ?? 0)
        }
        #expect(heads == heads.sorted())
        #expect(heads.first == 0)
        #expect(Set(catalog.chart(page).map(\.id)) == Set(pool.map(\.id)))

        #expect(planner.batches(page).flatMap(\.characterIDs) == pool.map(\.id))
        var generator = SeededGenerator(state: 1)
        let first = try #require(planner.makeLesson(page: page, progress: [:], state: .empty, now: Date(), using: &generator))
        #expect(first.newCharacterIDs == pool.prefix(first.newCharacterIDs.count).map(\.id))
    }

    @Test("The most common kanji open their themes", arguments: [
        (MojiKanjiTheme.people, "人"), (.time, "日"), (.numbers, "一"), (.describing, "大"),
        (.movement, "出"), (.study, "本"), (.work, "会"), (.oldForms, "國")
    ])
    func commonKanjiComeFirst(theme: MojiKanjiTheme, glyph: String) {
        #expect(catalog.pool(.kanji(theme)).first?.glyph == glyph)
    }

    @Test("A theme's symbol is one of its own kanji", arguments: MojiKanjiTheme.allCases)
    func symbolBelongsToTheTheme(theme: MojiKanjiTheme) {
        #expect(catalog.character("j-\(theme.symbol)")?.page == .kanji(theme))
    }

    @Test("A page is stored under a stable name")
    func pageNames() throws {
        for page in MojiPage.all {
            #expect(MojiPage(rawValue: page.rawValue) == page)
            let data = try JSONEncoder().encode([page])
            #expect(try JSONDecoder().decode([MojiPage].self, from: data) == [page])
        }
        #expect(Set(MojiPage.all.map(\.rawValue)).count == MojiPage.all.count)
        #expect(MojiPage.hiragana.rawValue == "hiragana")
        #expect(MojiPage.kanji(.people).rawValue == "kanji.people")
        #expect(MojiPage.kanji(.oldForms).rawValue == "kanji.old_forms")
        #expect(MojiPage(rawValue: "kanji") == nil)
        #expect(MojiPage(rawValue: "kanji_plus") == nil)
        #expect(MojiPage(rawValue: "kanji.nope") == nil)
        #expect(MojiPage(script: .kanji, theme: .names) == .kanji(.names))
        #expect(MojiPage(script: .katakana, theme: .names) == .katakana)
    }

    @Test("Old tab names still open the right tab")
    func storedScripts() {
        #expect(MojiScript(storedValue: "hiragana") == .hiragana)
        #expect(MojiScript(storedValue: "katakana") == .katakana)
        #expect(MojiScript(storedValue: "kanji") == .kanji)
        #expect(MojiScript(storedValue: "kanji_plus") == .kanji)
        #expect(MojiScript(storedValue: "kanji.people") == nil)
        #expect(MojiScript(storedValue: "") == nil)
    }
}
