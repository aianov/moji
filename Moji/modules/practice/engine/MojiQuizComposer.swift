import Foundation

struct MojiQuizComposer: Sendable {
    static let optionCount = 4
    static let lookAlikeOptionLimit = 2

    let catalog: MojiAlphabetCatalog

    func makeOrder<R: RandomNumberGenerator>(
        page: MojiPage,
        using generator: inout R
    ) -> [String] {
        catalog.pool(page).map(\.id).shuffled(using: &generator)
    }

    func makeQuestion<R: RandomNumberGenerator>(
        for characterID: String,
        mode: MojiAnswerMode = .standard,
        using generator: inout R
    ) -> MojiQuizQuestion? {
        guard let answer = catalog.character(characterID) else { return nil }

        let direction = self.direction(for: answer, side: mode.side, using: &generator)
        let input = self.input(mode.input, using: &generator)

        guard input == .choice else {
            return MojiQuizQuestion(
                characterID: answer.id,
                direction: direction,
                optionIDs: [],
                input: .typing
            )
        }

        var optionIDs = distractors(
            for: answer,
            count: Self.optionCount - 1,
            using: &generator
        ).map(\.id)
        optionIDs.append(answer.id)
        optionIDs.shuffle(using: &generator)

        return MojiQuizQuestion(
            characterID: answer.id,
            direction: direction,
            optionIDs: optionIDs,
            input: .choice
        )
    }

    func isPlayable(_ question: MojiQuizQuestion) -> Bool {
        guard let answer = catalog.character(question.characterID) else { return false }
        if question.direction == .romajiToGlyph, catalog.requiresGlyphPrompt(answer) {
            return false
        }
        switch question.input {
        case .choice:
            return question.optionIDs.contains(answer.id)
                && question.optionIDs.allSatisfy { catalog.character($0) != nil }
        case .typing:
            return true
        }
    }

    private func direction<R: RandomNumberGenerator>(
        for answer: MojiCharacter,
        side: MojiAnswerSide,
        using generator: inout R
    ) -> MojiQuizDirection {
        if catalog.requiresGlyphPrompt(answer) {
            return .glyphToRomaji
        }
        switch side {
        case .romaji:
            return .glyphToRomaji
        case .character:
            return .romajiToGlyph
        case .mixed:
            return Bool.random(using: &generator) ? .glyphToRomaji : .romajiToGlyph
        }
    }

    private func input<R: RandomNumberGenerator>(
        _ mode: MojiAnswerInput,
        using generator: inout R
    ) -> MojiQuizInput {
        switch mode {
        case .list:
            .choice
        case .keyboard:
            .typing
        case .mixed:
            Bool.random(using: &generator) ? .typing : .choice
        }
    }

    func distractors<R: RandomNumberGenerator>(
        for answer: MojiCharacter,
        count: Int,
        using generator: inout R
    ) -> [MojiCharacter] {
        var chosen: [MojiCharacter] = []
        var usedKeys: Set<String> = [answer.optionKey]
        var usedGlyphs: Set<String> = [answer.glyph]

        func take(_ candidate: MojiCharacter) {
            guard chosen.count < count,
                  candidate.id != answer.id,
                  !usedKeys.contains(candidate.optionKey),
                  !usedGlyphs.contains(candidate.glyph) else {
                return
            }
            chosen.append(candidate)
            usedKeys.insert(candidate.optionKey)
            usedGlyphs.insert(candidate.glyph)
        }

        let lookAlikeLimit = min(Self.lookAlikeOptionLimit, count)
        for candidate in catalog.lookAlikes(of: answer).shuffled(using: &generator) {
            guard chosen.count < lookAlikeLimit else { break }
            take(candidate)
        }
        for candidate in catalog.members(ofSection: answer.sectionID).shuffled(using: &generator) {
            guard chosen.count < count else { break }
            take(candidate)
        }
        for candidate in catalog.pool(answer.page).shuffled(using: &generator) {
            guard chosen.count < count else { break }
            take(candidate)
        }
        return chosen
    }
}
