import Testing
@testable import Moji

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

@Suite("Quiz composer")
struct MojiQuizComposerTests {
    private let catalog = MojiAlphabetCatalog.shared

    private var composer: MojiQuizComposer {
        MojiQuizComposer(catalog: catalog)
    }

    @Test("A session asks every character of its page exactly once", arguments: MojiPage.all)
    func orderCoversEveryCharacterOnce(page: MojiPage) {
        var generator = SeededGenerator(state: 7)
        let order = composer.makeOrder(page: page, using: &generator)
        let pool = catalog.pool(page).map(\.id)

        #expect(!pool.isEmpty)
        #expect(order.count == pool.count)
        #expect(Set(order).count == order.count)
        #expect(Set(order) == Set(pool))
    }

    @Test("Every question has four options and one right answer", arguments: MojiPage.all)
    func everyQuestionHasExactlyOneRightAnswer(page: MojiPage) throws {
        for character in catalog.pool(page) {
            let lookAlikes = Set(catalog.lookAlikes(of: character).map(\.id))
            for seed in 0..<12 {
                var generator = SeededGenerator(state: UInt64(seed) &* 31 &+ 1)
                let question = try #require(composer.makeQuestion(for: character.id, using: &generator))
                let options = question.optionIDs.compactMap { catalog.character($0) }

                #expect(options.count == MojiQuizComposer.optionCount)
                #expect(question.optionIDs.filter { $0 == character.id }.count == 1)
                #expect(Set(options.map(\.optionKey)).count == options.count)
                #expect(Set(options.map(\.glyph)).count == options.count)
                #expect(options.allSatisfy { $0.script == page.script })
                #expect(options.allSatisfy { $0.page == page || lookAlikes.contains($0.id) })
            }
        }
    }

    @Test("Kana spelled like another kana are asked glyph-first")
    func ambiguousKanaAreAskedGlyphFirst() throws {
        for id in ["h-wo", "h-di", "h-du", "k-di", "k-du"] {
            let character = try #require(catalog.character(id))
            #expect(catalog.requiresGlyphPrompt(character))

            for seed in 0..<20 {
                var generator = SeededGenerator(state: UInt64(seed))
                let question = try #require(composer.makeQuestion(for: id, using: &generator))
                #expect(question.direction == .glyphToRomaji)
            }
        }
    }

    @Test("Kanji meanings are unique in their theme", arguments: MojiKanjiTheme.allCases)
    func kanjiMeaningsAreUnique(theme: MojiKanjiTheme) {
        let pool = catalog.pool(.kanji(theme))
        let meanings = pool.compactMap(\.meaning)
        #expect(meanings.count == pool.count)
        #expect(Set(meanings).count == meanings.count)
        #expect(pool.allSatisfy { !catalog.requiresGlyphPrompt($0) })
    }

    @Test("Look-alikes know each other across themes")
    func lookAlikesCrossThemes() throws {
        var crossing = 0
        for group in MojiAlphabetData.kanjiLookAlikes {
            let members = group.compactMap { catalog.character("j-\($0)") }
            #expect(members.count == group.count, "\(group)")
            for member in members {
                let related = Set(catalog.lookAlikes(of: member).map(\.id))
                for other in members where other.id != member.id {
                    #expect(related.contains(other.id), "\(member.glyph) does not know \(other.glyph)")
                }
            }
            if Set(members.map(\.page)).count > 1 {
                crossing += 1
            }
        }
        #expect(crossing > 0)
    }

    @Test("A look-alike from another theme turns up among the options")
    func lookAlikeOptionFromAnotherTheme() throws {
        let group = try #require(MojiAlphabetData.kanjiLookAlikes.first { group in
            Set(group.compactMap { catalog.character("j-\($0)")?.page }).count > 1
        })
        let members = group.compactMap { catalog.character("j-\($0)") }
        let answer = try #require(members.first { member in
            members.contains { $0.page != member.page }
        })
        let strangers = Set(members.filter { $0.page != answer.page }.map(\.id))

        var offered = false
        for seed in 0..<40 where !offered {
            var generator = SeededGenerator(state: UInt64(seed) &+ 3)
            let question = try #require(composer.makeQuestion(for: answer.id, using: &generator))
            offered = question.optionIDs.contains(where: strangers.contains)
        }
        #expect(offered, "\(answer.glyph) never offered \(strangers)")
    }
}
