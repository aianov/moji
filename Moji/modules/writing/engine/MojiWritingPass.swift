import CoreGraphics
import Foundation

enum MojiWritingEvent: Equatable, Sendable {
    case reachedEnd(stroke: Int)
    case strokeDone(stroke: Int)
    case paused(stroke: Int)
    case written
    case failed(MojiTraceFailure, stroke: Int)
}

struct MojiWritingPass: Equatable, Sendable {
    let figure: MojiWritingFigure
    let stage: MojiWritingStage
    let tolerance: MojiTraceTolerance

    private let paths: [MojiStrokePath]
    private(set) var strokeIndex = 0
    private(set) var tracer: MojiStrokeTracer?

    init(figure: MojiWritingFigure, stage: MojiWritingStage, tolerance: MojiTraceTolerance = .standard) {
        let widened = tolerance.widened(by: stage.toleranceFactor)
        let paths = figure.strokes.map(MojiStrokePath.init)
        self.figure = figure
        self.stage = stage
        self.tolerance = widened
        self.paths = paths
        tracer = paths.first.map { MojiStrokeTracer(path: $0, tolerance: widened) }
    }

    var strokeCount: Int {
        paths.count
    }

    var isComplete: Bool {
        strokeIndex >= paths.count
    }

    var currentPath: MojiStrokePath? {
        tracer?.path
    }

    var doneStrokes: [[CGPoint]] {
        Array(figure.strokes.prefix(strokeIndex))
    }

    var isTouching: Bool {
        tracer?.isTouching ?? false
    }

    mutating func begin(at point: CGPoint) -> MojiWritingEvent? {
        guard var tracer else { return nil }
        let event = tracer.begin(at: point)
        self.tracer = tracer
        return settle(event)
    }

    mutating func move(to point: CGPoint) -> MojiWritingEvent? {
        guard var tracer else { return nil }
        let event = tracer.move(to: point)
        self.tracer = tracer
        return settle(event)
    }

    mutating func end(at point: CGPoint?) -> MojiWritingEvent? {
        guard var tracer else { return nil }
        let event = tracer.end(at: point)
        self.tracer = tracer
        return settle(event)
    }

    mutating func cancel() {
        tracer?.cancel()
    }

    mutating func retryStroke() {
        tracer?.reset()
    }

    private mutating func settle(_ event: MojiTraceEvent?) -> MojiWritingEvent? {
        switch event {
        case .reachedEnd:
            return .reachedEnd(stroke: strokeIndex)
        case .paused:
            return .paused(stroke: strokeIndex)
        case .completed:
            let done = strokeIndex
            strokeIndex += 1
            guard strokeIndex < paths.count else {
                tracer = nil
                return .written
            }
            tracer = MojiStrokeTracer(path: paths[strokeIndex], tolerance: tolerance)
            return .strokeDone(stroke: done)
        case .failed(let failure):
            return .failed(failure, stroke: strokeIndex)
        case .began, nil:
            return nil
        }
    }
}
