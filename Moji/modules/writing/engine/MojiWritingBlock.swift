import CoreGraphics
import Foundation

enum MojiWritingPhase: Equatable, Sendable {
    case writing
    case written
    case failed(MojiTraceFailure)
    case finished
}

struct MojiWritingBlock: Equatable, Sendable {
    let tolerance: MojiTraceTolerance

    private(set) var cards: [MojiWritingCard]
    private(set) var cursor = 0
    private(set) var pass: MojiWritingPass
    private(set) var phase: MojiWritingPhase = .writing
    private(set) var verdict: MojiWritingVerdict?

    init?(cards: [MojiWritingCard], tolerance: MojiTraceTolerance = .standard) {
        guard let first = cards.first else { return nil }
        self.tolerance = tolerance
        self.cards = cards
        pass = MojiWritingPass(figure: first.figure, stage: first.stage, tolerance: tolerance)
    }

    var card: MojiWritingCard {
        cards[cursor]
    }

    var writingsLeft: Int {
        cards.reduce(0) { $0 + $1.writingsLeft }
    }

    var writingsDone: Int {
        cards.reduce(0) { $0 + $1.writings }
    }

    var mistakes: Int {
        cards.reduce(0) { $0 + $1.mistakes }
    }

    var isFinished: Bool {
        phase == .finished
    }

    mutating func touchBegan(at point: CGPoint) -> MojiWritingEvent? {
        guard phase == .writing else { return nil }
        return settle(pass.begin(at: point))
    }

    mutating func touchMoved(to point: CGPoint) -> MojiWritingEvent? {
        guard phase == .writing else { return nil }
        return settle(pass.move(to: point))
    }

    mutating func touchEnded(at point: CGPoint?) -> MojiWritingEvent? {
        guard phase == .writing else { return nil }
        return settle(pass.end(at: point))
    }

    mutating func touchCancelled() {
        guard phase == .writing else { return }
        pass.cancel()
    }

    mutating func advance() {
        switch phase {
        case .written:
            guard let next = nextUnfinished(after: cursor) else {
                phase = .finished
                return
            }
            cursor = next
            pass = MojiWritingPass(figure: cards[next].figure, stage: cards[next].stage, tolerance: tolerance)
            phase = .writing
        case .failed:
            if card.stage == pass.stage {
                pass.retryStroke()
            } else {
                pass = MojiWritingPass(figure: card.figure, stage: card.stage, tolerance: tolerance)
            }
            phase = .writing
        case .writing, .finished:
            return
        }
        verdict = nil
    }

    private mutating func settle(_ event: MojiWritingEvent?) -> MojiWritingEvent? {
        switch event {
        case .written:
            verdict = cards[cursor].pass()
            phase = .written
        case .failed(let failure, _):
            verdict = cards[cursor].fail()
            phase = .failed(failure)
        case .reachedEnd, .strokeDone, nil:
            break
        }
        return event
    }

    private func nextUnfinished(after index: Int) -> Int? {
        for offset in 1...cards.count {
            let candidate = (index + offset) % cards.count
            if !cards[candidate].isFinished {
                return candidate
            }
        }
        return nil
    }
}
