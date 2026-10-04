import CoreGraphics
import Foundation

extension PracticeInteractionsStore {
    private static let drawingRetryPause: Duration = .milliseconds(650)

    func startDrawing(_ model: PracticeQuestionModel) {
        guard let figure = model.figure else {
            service.drawingBoard = nil
            return
        }
        service.drawingBoard = PracticeDrawingBoard(questionID: model.id, figure: figure)
    }

    func handleDrawing(_ touch: WritingTouch, on board: PracticeDrawingBoard) {
        guard service.drawingBoard === board,
              let model = service.currentQuestion,
              model.id == board.questionID else { return }
        var drawing = board.drawing
        var event: MojiWritingEvent?
        switch touch {
        case .began(let point):
            event = drawing.touchBegan(at: point)
        case .moved(let points):
            for point in points {
                guard let next = drawing.touchMoved(to: point) else { continue }
                event = next
                if !drawing.acceptsTouches { break }
            }
        case .ended(let point):
            event = drawing.touchEnded(at: point)
        case .cancelled:
            drawing.touchCancelled()
        }
        board.drawing = drawing
        syncDrawing(board)
        respondToDrawing(event, on: board, model: model)
    }

    func useDrawingHint(on board: PracticeDrawingBoard) {
        guard service.drawingBoard === board,
              case .question(let model) = service.stage,
              model.id == board.questionID else { return }
        var drawing = board.drawing
        guard drawing.useHint() else { return }
        board.drawing = drawing
        syncDrawing(board)
        if !settleDrawing(on: board, model: model) {
            MojiHaptics.selection()
        }
    }

    func giveUpDrawing(_ model: PracticeQuestionModel) {
        guard let board = service.drawingBoard, board.questionID == model.id else { return }
        var drawing = board.drawing
        drawing.giveUp()
        board.drawing = drawing
        syncDrawing(board)
    }

    private func respondToDrawing(
        _ event: MojiWritingEvent?,
        on board: PracticeDrawingBoard,
        model: PracticeQuestionModel
    ) {
        switch event {
        case .reachedEnd(let stroke), .strokeDone(let stroke):
            tickDrawing(stroke, on: board)
        case .written:
            settleDrawing(on: board, model: model)
        case .failed:
            if !settleDrawing(on: board, model: model) {
                MojiHaptics.warning()
            }
            scheduleDrawingRetry(on: board)
        case .paused, nil:
            break
        }
    }

    @discardableResult
    private func settleDrawing(on board: PracticeDrawingBoard, model: PracticeQuestionModel) -> Bool {
        guard case .question(let current) = service.stage, current.id == model.id else { return false }
        let drawn = MojiDrawnAnswer(board.drawing)
        guard drawn.isSettled else { return false }
        reveal(chosenID: nil, typed: nil, drawn: drawn)
        return true
    }

    private func tickDrawing(_ stroke: Int, on board: PracticeDrawingBoard) {
        let key = "\(board.passToken).\(stroke)"
        guard board.tickedStroke != key else { return }
        board.tickedStroke = key
        MojiHaptics.selection()
    }

    private func scheduleDrawingRetry(on board: PracticeDrawingBoard) {
        let token = UUID()
        board.retryToken = token
        Task {
            try? await Task.sleep(for: Self.drawingRetryPause)
            guard board.retryToken == token else { return }
            board.retryToken = nil
            var drawing = board.drawing
            drawing.retry()
            board.drawing = drawing
            board.passToken += 1
            syncDrawing(board)
        }
    }

    private func syncDrawing(_ board: PracticeDrawingBoard) {
        let drawing = board.drawing
        let pass = drawing.pass
        let tracer = pass.tracer
        let failure = drawing.failure.map { reason in
            WritingFailure(reason: reason, stroke: pass.strokeIndex, touch: tracer?.touchDown, verdict: .strokeAgain)
        }

        assignDrawing(\.strokeIndex, pass.strokeIndex, on: board)
        assignDrawing(\.ink, tracer?.ink ?? [], on: board)
        assignDrawing(\.isTouching, tracer?.isTouching ?? false, on: board)
        assignDrawing(\.reachedEnd, tracer?.hasReachedEnd ?? false, on: board)
        assignDrawing(\.isPaused, tracer?.isPaused ?? false, on: board)
        assignDrawing(\.resumePoint, tracer?.resumePoint, on: board)
        assignDrawing(\.failure, failure, on: board)
        assignDrawing(\.hint, drawing.hint, on: board)
        assignDrawing(\.canUseHint, drawing.canUseHint, on: board)
        assignDrawing(\.showsWholePhantom, drawing.showsWholeFigure, on: board)
        assignDrawing(\.showsCurrentStroke, drawing.showsCurrentStroke, on: board)
        assignDrawing(\.isDrawn, drawing.isDrawn, on: board)
        assignDrawing(\.isWritten, drawing.isPassed, on: board)
    }

    private func assignDrawing<Value: Equatable>(
        _ keyPath: ReferenceWritableKeyPath<PracticeDrawingBoard, Value>,
        _ value: Value,
        on board: PracticeDrawingBoard
    ) {
        guard board[keyPath: keyPath] != value else { return }
        board[keyPath: keyPath] = value
    }
}
