import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class PracticeDrawingBoard: WritingCanvasSource {
    let questionID: String
    let figure: MojiWritingFigure?

    var strokeIndex = 0
    var ink: [CGPoint] = []
    var isTouching = false
    var reachedEnd = false
    var isPaused = false
    var resumePoint: CGPoint?
    var failure: WritingFailure?
    var hint: MojiDrawingHint = .none
    var canUseHint = true
    var showsWholePhantom = false
    var showsCurrentStroke = false
    var isDrawn = false
    var isWritten = false
    var passToken = 0

    @ObservationIgnored var drawing: MojiMemoryDrawing
    @ObservationIgnored var tickedStroke: String?
    @ObservationIgnored var retryToken: UUID?

    init(questionID: String, figure: MojiWritingFigure) {
        self.questionID = questionID
        self.figure = figure
        drawing = MojiMemoryDrawing(figure: figure)
    }

    var currentStroke: [CGPoint]? {
        guard let figure, figure.strokes.indices.contains(strokeIndex) else { return nil }
        return figure.strokes[strokeIndex]
    }

    var doneStrokes: [[CGPoint]] {
        guard let figure else { return [] }
        return Array(figure.strokes.prefix(strokeIndex))
    }

    var showsPoints: Bool {
        showsCurrentStroke
    }
}
