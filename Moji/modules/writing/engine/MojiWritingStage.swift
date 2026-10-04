import CoreGraphics
import Foundation

enum MojiWritingStage: Int, CaseIterable, Comparable, Sendable {
    case phantom = 1
    case points = 2
    case memory = 3

    static func < (lhs: MojiWritingStage, rhs: MojiWritingStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var number: Int {
        rawValue
    }

    var showsPhantom: Bool {
        self == .phantom
    }

    var showsPoints: Bool {
        self != .memory
    }

    var toleranceFactor: CGFloat {
        switch self {
        case .phantom, .points: 1
        case .memory: 1.3
        }
    }

    var higher: MojiWritingStage? {
        MojiWritingStage(rawValue: rawValue + 1)
    }

    var lower: MojiWritingStage? {
        MojiWritingStage(rawValue: rawValue - 1)
    }

    var writingsToFinish: Int {
        MojiWritingStage.allCases.count - rawValue + 1
    }
}

enum MojiWritingVerdict: Equatable, Sendable {
    case stageUp(MojiWritingStage)
    case finished
    case strokeAgain
    case stageDown(MojiWritingStage)
}

struct MojiWritingCard: Identifiable, Equatable, Sendable {
    let id: String
    let figure: MojiWritingFigure
    private(set) var stage: MojiWritingStage = .phantom
    private(set) var isFinished = false
    private(set) var writings = 0
    private(set) var mistakes = 0

    init(id: String, figure: MojiWritingFigure) {
        self.id = id
        self.figure = figure
    }

    var writingsLeft: Int {
        isFinished ? 0 : stage.writingsToFinish
    }

    @discardableResult
    mutating func pass() -> MojiWritingVerdict {
        guard !isFinished else { return .finished }
        writings += 1
        guard let next = stage.higher else {
            isFinished = true
            return .finished
        }
        stage = next
        return .stageUp(next)
    }

    @discardableResult
    mutating func fail() -> MojiWritingVerdict {
        guard !isFinished else { return .finished }
        mistakes += 1
        guard let previous = stage.lower else { return .strokeAgain }
        stage = previous
        return .stageDown(previous)
    }
}
