import Foundation

struct PracticePresentedSession: Identifiable, Equatable {
    let page: MojiPage

    var id: String { page.rawValue }
}

enum PracticeStage: Equatable {
    case loading
    case question(PracticeQuestionModel)
    case revealed(PracticeQuestionModel, PracticeReveal)
    case finished(PracticeSummaryModel)
    case unavailable
}

struct PracticeReveal: Equatable {
    let chosenID: String?
    let isCorrect: Bool
    var typed: String? = nil
    var drawn: MojiDrawnAnswer? = nil

    var isGivenUp: Bool {
        chosenID == nil && typed == nil && drawn == nil
    }
}

enum PracticeAnswerStyle: Hashable {
    case choice
    case romaji
    case character
    case drawing
}

struct PracticePromptModel: Equatable {
    let title: String
    let subtitle: String?
    let isGlyph: Bool
    var isMeaning: Bool = false
}

struct PracticeOptionModel: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let isGlyph: Bool
    var detail: String? = nil
    var detailIsGlyph = false
}

enum PracticeLaunchState: Equatable {
    case fresh
    case inProgress(answered: Int, total: Int, correct: Int)
    case doneToday
}

struct PracticeQuestionModel: Identifiable, Equatable {
    let sessionID: UUID
    let page: MojiPage
    let index: Int
    let total: Int
    let correctSoFar: Int
    let combo: Int
    let direction: MojiQuizDirection
    let answerStyle: PracticeAnswerStyle
    let instruction: String
    let prompt: PracticePromptModel
    let options: [PracticeOptionModel]
    let answer: MojiCharacter
    var figure: MojiWritingFigure? = nil

    var id: String {
        "\(sessionID.uuidString)#\(index)"
    }

    var correctOptionID: String {
        answer.id
    }

    var correctOption: PracticeOptionModel? {
        options.first { $0.id == answer.id }
    }

    var isTyped: Bool {
        answerStyle == .romaji || answerStyle == .character
    }

    var isDrawn: Bool {
        answerStyle == .drawing
    }

    var hintText: String {
        switch answerStyle {
        case .choice, .drawing: ""
        case .romaji: answer.romaji.filter { $0 != "(" && $0 != ")" }
        case .character: answer.glyph
        }
    }

    var answerLines: [String] {
        answerLines(typed: nil)
    }

    func answerLines(typed: String?) -> [String] {
        guard let meaning = answer.meaning else {
            return ["\(answer.glyph) · \(answer.romaji)"]
        }
        if let typed, let other = MojiAnswerChecker.otherReading(spelledBy: typed, for: answer) {
            return ["\(answer.glyph) · \(other.line)", meaning]
        }
        return ["\(answer.glyph) · \(answer.readingLine)", meaning]
    }

    var fieldPlaceholder: String {
        guard answerStyle == .character else {
            return page.isKanji ? String(localized: "Reading in romaji") : String(localized: "Romaji")
        }
        return page.script.title
    }

    func accepts(_ typed: String) -> Bool {
        MojiAnswerChecker.accepts(typed, for: answer, direction: direction)
    }

    func answeredCount(after reveal: PracticeReveal?) -> Int {
        index + (reveal == nil ? 0 : 1)
    }

    func combo(after reveal: PracticeReveal?) -> Int {
        guard let reveal else { return combo }
        return reveal.isCorrect ? combo + 1 : 0
    }

    static func make(
        session: MojiPracticeSession,
        catalog: MojiAlphabetCatalog,
        strokes: MojiStrokeLibrary? = MojiStrokeLibrary.shared
    ) -> PracticeQuestionModel? {
        guard let question = session.current,
              let answer = catalog.character(question.characterID) else {
            return nil
        }

        let answerStyle: PracticeAnswerStyle
        switch question.input {
        case .choice:
            answerStyle = .choice
        case .typing:
            answerStyle = question.direction == .glyphToRomaji ? .romaji : .character
        case .drawing:
            answerStyle = .drawing
        }

        var options: [PracticeOptionModel] = []
        if answerStyle == .choice {
            options = question.optionIDs.compactMap { id in
                catalog.character(id).map { option(for: $0, direction: question.direction) }
            }
            guard options.contains(where: { $0.id == answer.id }) else { return nil }
        }

        var figure: MojiWritingFigure?
        if answerStyle == .drawing {
            guard question.direction == .romajiToGlyph,
                  let drawn = strokes?.figure(for: answer.glyph) else { return nil }
            figure = drawn
        }

        return PracticeQuestionModel(
            sessionID: session.id,
            page: session.page,
            index: session.answeredCount,
            total: session.total,
            correctSoFar: session.correctCount,
            combo: session.combo,
            direction: question.direction,
            answerStyle: answerStyle,
            instruction: instruction(
                script: session.script,
                direction: question.direction,
                answerStyle: answerStyle
            ),
            prompt: prompt(for: answer, direction: question.direction, answerStyle: answerStyle),
            options: options,
            answer: answer,
            figure: figure
        )
    }

    private static func option(
        for character: MojiCharacter,
        direction: MojiQuizDirection
    ) -> PracticeOptionModel {
        switch direction {
        case .glyphToRomaji:
            if let meaning = character.meaning {
                return PracticeOptionModel(
                    id: character.id,
                    title: meaning,
                    subtitle: character.readingLine,
                    isGlyph: false,
                    detail: character.glyph,
                    detailIsGlyph: true
                )
            }
            return PracticeOptionModel(
                id: character.id,
                title: character.romaji,
                subtitle: nil,
                isGlyph: false,
                detail: character.glyph,
                detailIsGlyph: true
            )
        case .romajiToGlyph:
            let detail = character.shortMeaning.map { "\(character.readingLine) · \($0)" } ?? character.romaji
            return PracticeOptionModel(
                id: character.id,
                title: character.glyph,
                subtitle: nil,
                isGlyph: true,
                detail: detail
            )
        }
    }

    private static func prompt(
        for answer: MojiCharacter,
        direction: MojiQuizDirection,
        answerStyle: PracticeAnswerStyle
    ) -> PracticePromptModel {
        switch direction {
        case .glyphToRomaji:
            return PracticePromptModel(
                title: answer.glyph,
                subtitle: answerStyle == .romaji ? answer.meaning : nil,
                isGlyph: true
            )
        case .romajiToGlyph:
            if let meaning = answer.meaning {
                return PracticePromptModel(
                    title: meaning,
                    subtitle: answer.readingLine,
                    isGlyph: false,
                    isMeaning: true
                )
            }
            return PracticePromptModel(
                title: answer.romaji,
                subtitle: nil,
                isGlyph: false
            )
        }
    }

    private static func instruction(
        script: MojiScript,
        direction: MojiQuizDirection,
        answerStyle: PracticeAnswerStyle
    ) -> String {
        switch (answerStyle, direction) {
        case (.choice, .glyphToRomaji):
            script.isKanji
                ? String(localized: "What does this kanji mean?")
                : String(localized: "What sound does this make?")
        case (.choice, .romajiToGlyph):
            script.isKanji
                ? String(localized: "Which kanji means this?")
                : String(localized: "Which character makes this sound?")
        case (.romaji, _):
            script.isKanji
                ? String(localized: "How do you read this kanji?")
                : String(localized: "Type this sound in romaji")
        case (.character, _):
            switch script {
            case .hiragana: String(localized: "Write this sound in hiragana")
            case .katakana: String(localized: "Write this sound in katakana")
            case .kanji: String(localized: "Write the kanji that means this")
            }
        case (.drawing, _):
            switch script {
            case .hiragana: String(localized: "Draw this sound in hiragana")
            case .katakana: String(localized: "Draw this sound in katakana")
            case .kanji: String(localized: "Draw the kanji that means this")
            }
        }
    }
}

struct PracticeSummaryModel: Equatable {
    let page: MojiPage
    let total: Int
    let correct: Int
    let activeSeconds: Double
    let bestCombo: Int
    let mistakes: [MojiCharacter]
    let streak: Int
    let extendedStreak: Bool

    var accuracy: Double {
        total > 0 ? Double(correct) / Double(total) : 0
    }

    static func make(
        completion: MojiPracticeCompletion,
        catalog: MojiAlphabetCatalog
    ) -> PracticeSummaryModel {
        let record = completion.record
        return PracticeSummaryModel(
            page: completion.page,
            total: record.total,
            correct: record.correct,
            activeSeconds: record.activeSeconds,
            bestCombo: record.bestCombo,
            mistakes: record.mistakeIDs.compactMap { catalog.character($0) },
            streak: completion.streak,
            extendedStreak: completion.extendedStreak
        )
    }
}
