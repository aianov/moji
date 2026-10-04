import Foundation

struct MojiAlphabetCatalog: Sendable {
    static let shared = MojiAlphabetCatalog(
        definitions: MojiAlphabetData.pages,
        lookAlikes: MojiAlphabetData.kanjiLookAlikes,
        language: .current
    )

    let language: MojiLanguage
    let pages: [MojiPage]

    private let sectionsByPage: [MojiPage: [MojiCharacterSection]]
    private let poolByPage: [MojiPage: [MojiCharacter]]
    private let chartByPage: [MojiPage: [MojiCharacter]]
    private let charactersByScript: [MojiScript: [MojiCharacter]]
    private let charactersByID: [String: MojiCharacter]
    private let membersBySection: [String: [MojiCharacter]]
    private let lookAlikeIDs: [String: [String]]
    private let glyphPromptOnlyIDs: Set<String>

    init(
        definitions: [MojiPageDefinition],
        lookAlikes extraLookAlikes: [[String]] = [],
        language: MojiLanguage = .en
    ) {
        self.language = language
        var pages: [MojiPage] = []
        var sectionsByPage: [MojiPage: [MojiCharacterSection]] = [:]
        var poolByPage: [MojiPage: [MojiCharacter]] = [:]
        var chartByPage: [MojiPage: [MojiCharacter]] = [:]
        var charactersByScript: [MojiScript: [MojiCharacter]] = [:]
        var charactersByID: [String: MojiCharacter] = [:]
        var membersBySection: [String: [MojiCharacter]] = [:]
        var idByGlyph: [MojiScript: [String: String]] = [:]
        var lookAlikeGroups: [[String]] = []
        var glyphPromptOnlyIDs: Set<String> = []

        for definition in definitions {
            let page = definition.page
            var sections: [MojiCharacterSection] = []
            var chart: [MojiCharacter] = []
            var seenOptionKeys: Set<String> = []

            for sectionDefinition in definition.sections {
                let sectionID = "\(page.rawValue).\(sectionDefinition.key)"
                var slots: [MojiCharacterSlot] = []
                var members: [MojiCharacter] = []

                for (index, cell) in sectionDefinition.cells.enumerated() {
                    let character: MojiCharacter
                    switch cell {
                    case .gap:
                        slots.append(.gap("\(sectionID).gap.\(index)"))
                        continue
                    case let .kana(glyph, romaji, idSuffix):
                        character = MojiCharacter(
                            id: "\(definition.idPrefix)-\(idSuffix ?? romaji)",
                            script: page.script,
                            page: page,
                            sectionID: sectionID,
                            glyph: glyph,
                            romaji: romaji,
                            reading: nil,
                            meaning: nil
                        )
                    case let .kanji(glyph, romaji, reading, meaning):
                        character = MojiCharacter(
                            id: "\(definition.idPrefix)-\(glyph)",
                            script: page.script,
                            page: page,
                            sectionID: sectionID,
                            glyph: glyph,
                            romaji: romaji,
                            reading: reading,
                            meaning: MojiAlphabetData.meaning(of: glyph, english: meaning, in: language),
                            otherReadings: MojiAlphabetData.otherReadings(of: glyph)
                        )
                    }

                    assert(charactersByID[character.id] == nil, "Duplicate character id \(character.id)")
                    charactersByID[character.id] = character
                    idByGlyph[page.script, default: [:]][character.glyph] = character.id
                    slots.append(.character(character))
                    members.append(character)
                    chart.append(character)

                    if seenOptionKeys.contains(character.optionKey) {
                        glyphPromptOnlyIDs.insert(character.id)
                    } else {
                        seenOptionKeys.insert(character.optionKey)
                    }
                }

                membersBySection[sectionID] = members
                sections.append(
                    MojiCharacterSection(
                        id: sectionID,
                        page: page,
                        title: sectionDefinition.title.map { String(localized: $0) },
                        subtitle: sectionDefinition.subtitle.map { String(localized: $0) },
                        columns: sectionDefinition.columns,
                        slots: slots
                    )
                )
            }

            lookAlikeGroups += definition.lookAlikes
            pages.append(page)
            sectionsByPage[page] = sections
            chartByPage[page] = chart
            poolByPage[page] = Self.lessonPool(chart, order: definition.lessonOrder)
            charactersByScript[page.script, default: []] += chart
        }

        var lookAlikeIDs: [String: [String]] = [:]
        for group in lookAlikeGroups + extraLookAlikes {
            for glyphs in idByGlyph.values {
                let ids = group.compactMap { glyphs[$0] }
                guard ids.count > 1 else { continue }
                for id in ids {
                    var related = lookAlikeIDs[id] ?? []
                    for other in ids where other != id && !related.contains(other) {
                        related.append(other)
                    }
                    lookAlikeIDs[id] = related
                }
            }
        }

        self.pages = pages
        self.sectionsByPage = sectionsByPage
        self.poolByPage = poolByPage
        self.chartByPage = chartByPage
        self.charactersByScript = charactersByScript
        self.charactersByID = charactersByID
        self.membersBySection = membersBySection
        self.lookAlikeIDs = lookAlikeIDs
        self.glyphPromptOnlyIDs = glyphPromptOnlyIDs
    }

    private static func lessonPool(_ chart: [MojiCharacter], order: String?) -> [MojiCharacter] {
        guard let order else { return chart }
        let byGlyph = Dictionary(chart.map { ($0.glyph, $0) }, uniquingKeysWith: { first, _ in first })
        var pool: [MojiCharacter] = []
        var placed: Set<String> = []
        for glyph in order.map(String.init) {
            guard let character = byGlyph[glyph], placed.insert(character.id).inserted else { continue }
            pool.append(character)
        }
        assert(pool.count == chart.count, "Lesson order of \(chart.first?.page.rawValue ?? "?") misses kanji")
        return pool + chart.filter { !placed.contains($0.id) }
    }

    func pages(_ script: MojiScript) -> [MojiPage] {
        pages.filter { $0.script == script }
    }

    func sections(_ page: MojiPage) -> [MojiCharacterSection] {
        sectionsByPage[page] ?? []
    }

    func pool(_ page: MojiPage) -> [MojiCharacter] {
        poolByPage[page] ?? []
    }

    func chart(_ page: MojiPage) -> [MojiCharacter] {
        chartByPage[page] ?? []
    }

    func characters(_ script: MojiScript) -> [MojiCharacter] {
        charactersByScript[script] ?? []
    }

    func character(_ id: String) -> MojiCharacter? {
        charactersByID[id]
    }

    func members(ofSection sectionID: String) -> [MojiCharacter] {
        membersBySection[sectionID] ?? []
    }

    func lookAlikes(of character: MojiCharacter) -> [MojiCharacter] {
        (lookAlikeIDs[character.id] ?? []).compactMap { charactersByID[$0] }
    }

    func requiresGlyphPrompt(_ character: MojiCharacter) -> Bool {
        glyphPromptOnlyIDs.contains(character.id)
    }
}
