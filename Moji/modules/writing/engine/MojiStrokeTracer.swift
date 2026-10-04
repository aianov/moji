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
        startRadius: 0.17,
        corridor: 0.17,
        backtrack: 0.05,
        lookAhead: 0.2,
        finishShare: 0.3,
        finishFloor: 0.012,
        finishCeiling: 0.04,
        finishRadius: 0.14,
        finishReach: 0.24,
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
}

enum MojiTracePhase: Equatable, Sendable {
    case waiting
    case tracing
    case reachedEnd
    case paused
    case completed
    case failed(MojiTraceFailure)
}

enum MojiTraceEvent: Equatable, Sendable {
    case began
    case reachedEnd
    case paused
    case completed
    case failed(MojiTraceFailure)
}

struct MojiStrokeTracer: Equatable, Sendable {
    let path: MojiStrokePath
    let tolerance: MojiTraceTolerance

    private(set) var phase: MojiTracePhase = .waiting
    private(set) var progress: CGFloat = 0
    private(set) var touchDown: CGPoint?
    private var last: CGPoint?
    private var touchDownProgress: CGFloat = 0
    private var resumedFrom: CGFloat?

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

    var isPaused: Bool {
        phase == .paused
    }

    var hasReachedEnd: Bool {
        phase == .reachedEnd || phase == .completed
    }

    var resumePoint: CGPoint? {
        switch phase {
        case .paused:
            path.point(at: progress)
        case .tracing, .reachedEnd:
            resumedFrom.map { path.point(at: $0) }
        case .waiting, .completed, .failed:
            nil
        }
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
        case .paused:
            path.prefix(through: progress)
        case .tracing, .reachedEnd, .failed:
            touchDown == nil ? [] : path.prefix(through: progress)
        }
    }

    mutating func begin(at point: CGPoint) -> MojiTraceEvent? {
        let anchor: CGFloat
        switch phase {
        case .waiting:
            anchor = 0
        case .paused:
            anchor = progress
        case .tracing, .reachedEnd, .completed, .failed:
            return nil
        }
        touchDown = point
        guard MojiStrokePath.distance(point, path.point(at: anchor)) <= tolerance.startRadius else {
            return fail(.wrongStart)
        }
        resumedFrom = isPaused ? anchor : nil
        last = point
        progress = max(anchor, path.closest(to: point, within: anchor...(anchor + tolerance.startRadius)).position)
        touchDownProgress = progress
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
            return lift()
        case .waiting, .paused, .completed, .failed:
            return event
        }
    }

    mutating func cancel() {
        guard isTouching else { return }
        _ = lift()
    }

    mutating func reset() {
        phase = .waiting
        progress = 0
        touchDown = nil
        last = nil
        touchDownProgress = 0
        resumedFrom = nil
    }

    private mutating func lift() -> MojiTraceEvent? {
        last = nil
        guard progress - touchDownProgress >= tolerance.tapSlop else {
            guard let resumedFrom else {
                reset()
                return nil
            }
            progress = resumedFrom
            self.resumedFrom = nil
            phase = .paused
            return nil
        }
        resumedFrom = nil
        phase = .paused
        return .paused
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
