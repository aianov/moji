import Foundation

enum MojiAnswerInput: String, Codable, CaseIterable, Identifiable, Sendable {
    case list
    case keyboard
    case mixed
    case drawing

    var id: String { rawValue }
}

enum MojiAnswerSide: String, Codable, CaseIterable, Identifiable, Sendable {
    case romaji
    case character
    case mixed

    var id: String { rawValue }
}

struct MojiAnswerMode: Codable, Equatable, Hashable, Sendable {
    var input: MojiAnswerInput
    var side: MojiAnswerSide

    static let standard = MojiAnswerMode(input: .list, side: .mixed)

    init(input: MojiAnswerInput, side: MojiAnswerSide) {
        self.input = input
        self.side = side
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        input = (try? container.decode(MojiAnswerInput.self, forKey: .input)) ?? Self.standard.input
        side = (try? container.decode(MojiAnswerSide.self, forKey: .side)) ?? Self.standard.side
    }

    var askedSide: MojiAnswerSide {
        input == .drawing ? .character : side
    }
}
