import Testing
@testable import Moji

@Suite("Localized data")
struct MojiLocalizationTests {
    @Test("Every kanji has a meaning in every language, unique in its theme", arguments: MojiLanguage.allCases)
    func meaningsAreCompleteAndUnique(language: MojiLanguage) {
        let catalog = MojiAlphabetCatalog(
            definitions: MojiAlphabetData.pages,
            lookAlikes: MojiAlphabetData.kanjiLookAlikes,
            language: language
        )
        #expect(catalog.pages(.kanji).count == MojiKanjiTheme.allCases.count)
        for page in catalog.pages(.kanji) {
            let pool = catalog.pool(page)
            let meanings = pool.compactMap(\.meaning)

            #expect(meanings.count == pool.count, "\(page.rawValue)")
            #expect(Set(meanings).count == meanings.count, "\(page.rawValue)")
            if language == .ru {
                let missing = pool.filter { MojiAlphabetData.kanjiMeaningsRU[$0.glyph] == nil }.map(\.glyph)
                #expect(missing.isEmpty, "No Russian meaning for \(missing)")
            }
        }
    }

    @Test("The Russian table has no kanji that is not in a theme")
    func russianTableHasNoStrays() {
        let glyphs = Set(MojiAlphabetCatalog.shared.characters(.kanji).map(\.glyph))
        let strays = MojiAlphabetData.kanjiMeaningsRU.keys.filter { !glyphs.contains($0) }
        #expect(strays.isEmpty, "Not in any theme: \(strays.sorted())")
    }

    @Test("Every theme and section has a title and a subtitle")
    func themeTextsArePresent() {
        for theme in MojiKanjiTheme.allCases {
            #expect(!theme.title.isEmpty, "\(theme.rawValue)")
            #expect(!theme.subtitle.isEmpty, "\(theme.rawValue)")
            #expect(theme.symbol.count == 1, "\(theme.rawValue)")
            for section in MojiAlphabetCatalog.shared.sections(.kanji(theme)) {
                #expect(section.title?.isEmpty == false, "\(section.id)")
                #expect(section.subtitle?.isEmpty == false, "\(section.id)")
            }
        }
        #expect(Set(MojiKanjiTheme.allCases.map(\.title)).count == MojiKanjiTheme.allCases.count)
        #expect(Set(MojiKanjiTheme.allCases.map(\.symbol)).count == MojiKanjiTheme.allCases.count)
    }

    @Test("A chart cell keeps the first sense and drops Japanese hints only", arguments: [
        ("hand over, cross", "hand over"),
        ("persist (頑張る)", "persist"),
        ("I (boys)", "I (boys)"),
        ("-тель (тот, кто)", "-тель (тот, кто)"),
        ("полдень (午前, 午後)", "полдень"),
        ("получать (вежливо), вершина", "получать (вежливо)"),
        ("оставаться, задерживать (留学)", "оставаться")
    ])
    func shortMeaning(meaning: String, expected: String) {
        let character = MojiCharacter(
            id: "j-test",
            script: .kanji,
            page: .kanji(.study),
            sectionID: "kanji.study.test",
            glyph: "試",
            romaji: "tame(su)",
            reading: "ため(す)",
            meaning: meaning
        )
        #expect(character.shortMeaning == expected)
    }
}
