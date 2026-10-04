import CoreGraphics
import Foundation

enum MojiDrawingHint: Int, Comparable, Sendable {
    case none
    case stroke
    case whole

    init(mistakes: Int) {
        switch mistakes {
        case ..<1: self = .none
        case 1: self = .stroke
        default: self = .whole
        }
    }

    static func < (lhs: MojiDrawingHint, rhs: MojiDrawingHint) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct MojiMemoryDrawing: Equatable, Sendable {
    private(set) var pass: MojiWritingPass
    private(set) var failures = 0
    private(set) var hints = 0
    private(set) var failure: MojiTraceFailure?
    private(set) var revealedStroke: Int?
    private(set) var hasGivenUp = false

    init(figure: MojiWritingFigure, tolerance: MojiTraceTolerance = .standard) {
        pass = MojiWritingPass(figure: figure, stage: .memory, tolerance: tolerance)
    }

    var mistakes: Int {
        failures + hints
    }

    var hint: MojiDrawingHint {
        hasGivenUp ? .whole : MojiDrawingHint(mistakes: mistakes)
    }

    var isDrawn: Bool {
        pass.isComplete
    }

    var isPassed: Bool {
        isDrawn && hint < .whole
    }

    var acceptsTouches: Bool {
        !isDrawn && failure == nil
    }

    var canUseHint: Bool {
        !isDrawn && hint < .whole
    }

    var showsWholeFigure: Bool {
        !isDrawn && hint == .whole
    }

    var showsCurrentStroke: Bool {
        guard !isDrawn else { return false }
        return hint == .whole
            || failure != nil
            || revealedStroke == pass.strokeIndex
            || pass.tracer?.isPaused == true
    }

    mutating func touchBegan(at point: CGPoint) -> MojiWritingEvent? {
        guard acceptsTouches else { return nil }
        return settle(pass.begin(at: point))
    }

    mutating func touchMoved(to point: CGPoint) -> MojiWritingEvent? {
        guard acceptsTouches else { return nil }
        return settle(pass.move(to: point))
    }

    mutating func touchEnded(at point: CGPoint?) -> MojiWritingEvent? {
        guard acceptsTouches else { return nil }
        return settle(pass.end(at: point))
    }

    mutating func touchCancelled() {
        guard acceptsTouches else { return }
        pass.cancel()
    }

    @discardableResult
    mutating func useHint() -> Bool {
        guard canUseHint else { return false }
        hints += 1
        if mistakes == 1 {
            revealedStroke = pass.strokeIndex
        }
        return true
    }

    mutating func giveUp() {
        guard !isDrawn else { return }
        hasGivenUp = true
    }

    mutating func retry() {
        guard failure != nil else { return }
        failure = nil
        pass.retryStroke()
    }

    private mutating func settle(_ event: MojiWritingEvent?) -> MojiWritingEvent? {
        guard case .failed(let reason, let stroke) = event else { return event }
        failure = reason
        guard hint < .whole else { return event }
        failures += 1
        if mistakes == 1 {
            revealedStroke = stroke
        }
        return event
    }
}
