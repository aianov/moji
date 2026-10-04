import CoreGraphics
import Foundation

enum WritingTouch: Equatable {
    case began(CGPoint)
    case moved([CGPoint])
    case ended(CGPoint)
    case cancelled
}

struct WritingFailure: Equatable {
    let reason: MojiTraceFailure
    let stroke: Int
    let touch: CGPoint?
    let verdict: MojiWritingVerdict?

    var title: String {
        switch reason {
        case .wrongStart: String(localized: "This stroke starts elsewhere")
        case .offLine: String(localized: "Off the line")
        case .backwards: String(localized: "Wrong direction")
        }
    }

    var detail: String? {
        switch verdict {
        case .stageDown(let stage):
            String(localized: "Back to stage \(stage.number)")
        case .strokeAgain:
            String(localized: "Try this stroke again")
        case .stageUp, .finished, nil:
            nil
        }
    }
}

struct WritingResult: Identifiable, Equatable {
    let character: MojiCharacter
    let mistakes: Int

    var id: String { character.id }

    var isClean: Bool {
        mistakes == 0
    }
}

struct WritingPrompt: Equatable {
    let title: String
    let subtitle: String?
    let isKana: Bool

    init(_ character: MojiCharacter) {
        if let meaning = character.meaning {
            title = meaning
            subtitle = character.readingLine
            isKana = false
        } else {
            title = character.romaji
            subtitle = character.script == .katakana ? Self.hiragana(character.glyph) : nil
            isKana = true
        }
    }

    static func hiragana(_ text: String) -> String {
        var result = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if (0x30A1...0x30F6).contains(scalar.value), let shifted = Unicode.Scalar(scalar.value - 0x60) {
                result.append(shifted)
            } else {
                result.append(scalar)
            }
        }
        return String(result)
    }
}

extension MojiWritingStage {
    var caption: String {
        switch self {
        case .phantom: String(localized: "Trace over the outline")
        case .points: String(localized: "Go from point to point")
        case .memory: String(localized: "Write it from memory")
        }
    }
}
