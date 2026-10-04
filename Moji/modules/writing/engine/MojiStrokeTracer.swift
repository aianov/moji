import CoreGraphics
import Foundation

struct MojiTraceTolerance: Equatable, Sendable {
    var startRadius: CGFloat
    var corridor: CGFloat
    var backtrack: CGFloat
    var lookAhead: CGFloat
    var finishShare: CGFloat
    var finishFloor: CGFloat
    var finishCeiling: CGFloat
    var finishRadius: CGFloat
    var finishReach: CGFloat
    var tapSlop: CGFloat
    var step: CGFloat

    static let standard = MojiTraceTolerance(
        startRadius: 0.085,
        corridor: 0.085,
        backtrack: 0.025,
        lookAhead: 0.1,
        finishShare: 0.3,
        finishFloor: 0.012,
        finishCeiling: 0.04,
        finishRadius: 0.07,
        finishReach: 0.12,
        tapSlop: 0.02,
        step: 0.008
    )

    func widened(by factor: CGFloat) -> MojiTraceTolerance {
        var result = self
        result.startRadius *= factor
        result.corridor *= factor
        result.lookAhead *= factor
        result.finishRadius *= factor
        result.finishReach *= factor
        return result
    }

    func finishSlack(forLength length: CGFloat) -> CGFloat {
        min(max(length * finishShare, finishFloor), finishCeiling)
    }
}

enum MojiTraceFailure: String, Equatable, Sendable {
    case wrongStart
    case offLine
    case backwards
    case liftedEarly
}

enum MojiTracePhase: Equatable, Sendable {
    case waiting
    case tracing
    case reachedEnd
    case completed
    case failed(MojiTraceFailure)
}

enum MojiTraceEvent: Equatable, Sendable {
    case began
    case reachedEnd
    case completed
    case failed(MojiTraceFailure)
}

struct MojiStrokeTracer: Equatable, Sendable {
    let path: MojiStrokePath
    let tolerance: MojiTraceTolerance

    private(set) var phase: MojiTracePhase = .waiting
    private(set) var progress: CGFloat = 0
    private(set) var travel: CGFloat = 0
    private(set) var touchDown: CGPoint?
    private var last: CGPoint?

    init(path: MojiStrokePath, tolerance: MojiTraceTolerance = .standard) {
        self.path = path
        self.tolerance = tolerance
    }

    var finishPosition: CGFloat {
        max(0, path.length - tolerance.finishSlack(forLength: path.length))
    }

    var isTouching: Bool {
        phase == .tracing || phase == .reachedEnd
    }

    var hasReachedEnd: Bool {
        phase == .reachedEnd || phase == .completed
    }

    var fraction: CGFloat {
        guard path.length > 0 else { return hasReachedEnd ? 1 : 0 }
        return min(1, progress / path.length)
    }

    var ink: [CGPoint] {
        switch phase {
        case .waiting:
            []
        case .completed:
            path.points
        case .tracing, .reachedEnd, .failed:
            touchDown == nil ? [] : path.prefix(through: progress)
        }
    }

    mutating func begin(at point: CGPoint) -> MojiTraceEvent? {
        guard phase == .waiting else { return nil }
        touchDown = point
        guard MojiStrokePath.distance(point, path.start) <= tolerance.startRadius else {
            return fail(.wrongStart)
        }
        last = point
        travel = 0
        progress = path.closest(to: point, within: 0...tolerance.startRadius).position
        phase = .tracing
        guard reachesEnd(from: point) else { return .began }
        phase = .reachedEnd
        return .reachedEnd
    }

    mutating func move(to point: CGPoint) -> MojiTraceEvent? {
        guard isTouching, let from = last else { return nil }
        let gap = MojiStrokePath.distance(from, point)
        guard gap > 0 else { return nil }
        let steps = max(1, Int((gap / tolerance.step).rounded(.up)))
        var event: MojiTraceEvent?
        for index in 1...steps {
            let share = CGFloat(index) / CGFloat(steps)
            let sample = CGPoint(x: from.x + (point.x - from.x) * share, y: from.y + (point.y - from.y) * share)
            travel += gap / CGFloat(steps)
            last = sample
            if let next = follow(sample) {
                event = next
                if case .failed = next { break }
            }
        }
        return event
    }

    mutating func end(at point: CGPoint?) -> MojiTraceEvent? {
        var event: MojiTraceEvent?
        if let point {
            event = move(to: point)
        }
        switch phase {
        case .reachedEnd:
            progress = path.length
            phase = .completed
            return .completed
        case .tracing:
            guard travel >= tolerance.tapSlop else {
                reset()
                return nil
            }
            return fail(.liftedEarly)
        case .waiting, .completed, .failed:
            return event
        }
    }

    mutating func cancel() {
        guard isTouching else { return }
        reset()
    }

    mutating func reset() {
        phase = .waiting
        progress = 0
        travel = 0
        touchDown = nil
        last = nil
    }

    private mutating func follow(_ sample: CGPoint) -> MojiTraceEvent? {
        let ahead = path.closest(to: sample, within: progress...(progress + tolerance.lookAhead))
        let lower = max(0, progress - tolerance.backtrack)
        let slack = lower < progress ? path.closest(to: sample, within: lower...progress).distance : .infinity

        guard min(ahead.distance, slack) <= tolerance.corridor else {
            guard phase == .tracing else { return nil }
            let behind = lower > 0 ? path.closest(to: sample, within: 0...lower).distance : .infinity
            return fail(behind <= tolerance.corridor ? .backwards : .offLine)
        }

        if ahead.distance <= tolerance.corridor {
            progress = max(progress, ahead.position)
        }
        guard phase == .tracing, reachesEnd(from: sample) else { return nil }
        phase = .reachedEnd
        return .reachedEnd
    }

    private func reachesEnd(from point: CGPoint) -> Bool {
        if progress >= finishPosition {
            return true
        }
        return progress >= path.length - tolerance.finishReach
            && MojiStrokePath.distance(point, path.end) <= tolerance.finishRadius
    }

    private mutating func fail(_ failure: MojiTraceFailure) -> MojiTraceEvent {
        phase = .failed(failure)
        return .failed(failure)
    }
}
