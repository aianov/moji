import CoreGraphics
import Foundation
import Testing
@testable import Moji

@Suite("Drawing from memory")
struct MojiMemoryDrawingTests {
    private func makeDrawing(_ text: String) throws -> MojiMemoryDrawing {
        MojiMemoryDrawing(figure: try WritingFixture.figure(text))
    }

    @discardableResult
    private func draw(_ drawing: inout MojiMemoryDrawing, from start: CGFloat = 0, to end: CGFloat? = nil) throws -> [MojiWritingEvent] {
        let path = try #require(drawing.pass.currentPath)
        let points = WritingFixture.finger(along: path, from: start, to: end, wobble: 0.01)
        var events: [MojiWritingEvent] = []
        if let event = drawing.touchBegan(at: points[0]) {
            events.append(event)
        }
        for point in points.dropFirst() {
            if let event = drawing.touchMoved(to: point) {
                events.append(event)
            }
        }
        if let event = drawing.touchEnded(at: points.last) {
            events.append(event)
        }
        return events
    }

    private func finish(_ drawing: inout MojiMemoryDrawing) throws {
        var strokes = 0
        while !drawing.isDrawn, strokes < 40 {
            try draw(&drawing)
            strokes += 1
        }
    }

    private func slip(_ drawing: inout MojiMemoryDrawing) throws -> MojiWritingEvent? {
        let path = try #require(drawing.pass.currentPath)
        let wrong = CGPoint(x: path.start.x + 0.4, y: path.start.y)
        return drawing.touchBegan(at: wrong.x > 0.95 ? CGPoint(x: path.start.x - 0.4, y: path.start.y) : wrong)
    }

    @Test("Hint levels follow the mistakes: none, the stroke, the whole character")
    func levels() {
        #expect(MojiDrawingHint(mistakes: 0) == .none)
        #expect(MojiDrawingHint(mistakes: 1) == .stroke)
        #expect(MojiDrawingHint(mistakes: 2) == .whole)
        #expect(MojiDrawingHint(mistakes: 7) == .whole)
        #expect(MojiDrawingHint.none < .stroke && MojiDrawingHint.stroke < .whole)
    }

    @Test("Drawn without a slip, the character never shows a hint")
    func clean() throws {
        var drawing = try makeDrawing("日")
        #expect(drawing.pass.stage == .memory)
        #expect(drawing.canUseHint)
        var showedHint = false
        while !drawing.isDrawn {
            try draw(&drawing)
            showedHint = showedHint || drawing.showsCurrentStroke || drawing.showsWholeFigure
        }
        #expect(!showedHint)
        #expect(drawing.isPassed)
        #expect(drawing.mistakes == 0)
        #expect(drawing.hint == .none)
        #expect(!drawing.canUseHint)
        #expect(!drawing.acceptsTouches)
    }

    @Test("A first slip shows that stroke until it is drawn, then the drawing goes on from memory")
    func firstSlip() throws {
        var drawing = try makeDrawing("日")
        #expect(try draw(&drawing).last == .strokeDone(stroke: 0))

        #expect(try slip(&drawing) == .failed(.wrongStart, stroke: 1))
        #expect(drawing.failure == .wrongStart)
        #expect(drawing.mistakes == 1)
        #expect(drawing.hint == .stroke)
        #expect(drawing.revealedStroke == 1)
        #expect(drawing.showsCurrentStroke)
        #expect(!drawing.showsWholeFigure)
        #expect(!drawing.acceptsTouches)
        #expect(drawing.touchBegan(at: try #require(drawing.pass.currentPath).start) == nil)

        drawing.retry()
        #expect(drawing.failure == nil)
        #expect(drawing.acceptsTouches)
        #expect(drawing.showsCurrentStroke)
        #expect(drawing.pass.strokeIndex == 1)
        #expect(drawing.pass.tracer?.phase == .waiting)

        #expect(try draw(&drawing).last == .strokeDone(stroke: 1))
        #expect(!drawing.showsCurrentStroke)
        try finish(&drawing)
        #expect(drawing.isDrawn)
        #expect(drawing.isPassed)
        #expect(drawing.mistakes == 1)
        #expect(drawing.hint == .stroke)
    }

    @Test("A second slip shows the whole character, and slips after it no longer count")
    func secondSlip() throws {
        var drawing = try makeDrawing("日")
        _ = try slip(&drawing)
        drawing.retry()
        #expect(drawing.hint == .stroke)

        #expect(try slip(&drawing) == .failed(.wrongStart, stroke: 0))
        #expect(drawing.mistakes == 2)
        #expect(drawing.hint == .whole)
        #expect(drawing.showsWholeFigure)
        #expect(drawing.showsCurrentStroke)
        #expect(!drawing.canUseHint)
        let tappedAfterWhole = drawing.useHint()
        #expect(!tappedAfterWhole)
        #expect(drawing.hints == 0)

        drawing.retry()
        _ = try slip(&drawing)
        #expect(drawing.failures == 2)
        drawing.retry()
        try finish(&drawing)
        #expect(drawing.isDrawn)
        #expect(!drawing.isPassed)
        #expect(!drawing.showsWholeFigure)
        #expect(drawing.hint == .whole)
    }

    @Test("Hint taps are mistakes: the first shows the stroke, the second the whole character")
    func hintTaps() throws {
        var drawing = try makeDrawing("十")
        let first = drawing.useHint()
        #expect(first)
        #expect(drawing.hints == 1)
        #expect(drawing.hint == .stroke)
        #expect(drawing.revealedStroke == 0)
        #expect(drawing.showsCurrentStroke)
        #expect(!drawing.showsWholeFigure)
        let second = drawing.useHint()
        #expect(second)
        #expect(drawing.hint == .whole)
        #expect(drawing.showsWholeFigure)
        let third = drawing.useHint()
        #expect(!third)
        #expect(drawing.hints == 2)
        #expect(drawing.mistakes == 2)

        var once = try makeDrawing("十")
        once.useHint()
        try finish(&once)
        #expect(once.isPassed)
        #expect(once.mistakes == 1)

        var mixed = try makeDrawing("十")
        _ = try slip(&mixed)
        mixed.retry()
        let tapped = mixed.useHint()
        #expect(tapped)
        #expect(mixed.hint == .whole)
        #expect(mixed.failures == 1)
        #expect(mixed.hints == 1)
    }

    @Test("Lifting early is no mistake: the rest of the stroke shows until the drawing goes on")
    func pause() throws {
        var drawing = try makeDrawing("一")
        let path = try #require(drawing.pass.currentPath)
        #expect(try draw(&drawing, to: path.length * 0.5) == [.paused(stroke: 0)])
        #expect(drawing.mistakes == 0)
        #expect(drawing.hint == .none)
        #expect(drawing.pass.tracer?.isPaused == true)
        #expect(drawing.showsCurrentStroke)
        #expect(drawing.acceptsTouches)

        let kept = try #require(drawing.pass.tracer?.progress)
        #expect(try draw(&drawing, from: kept).last == .written)
        #expect(drawing.isPassed)
        #expect(drawing.mistakes == 0)
    }

    @Test("Giving up shows the whole character, which can still be traced but never passes")
    func givingUp() throws {
        var drawing = try makeDrawing("十")
        drawing.giveUp()
        #expect(drawing.hint == .whole)
        #expect(drawing.showsWholeFigure)
        #expect(!drawing.canUseHint)
        #expect(drawing.mistakes == 0)
        try finish(&drawing)
        #expect(drawing.isDrawn)
        #expect(!drawing.isPassed)
    }

    @Test("A kana pair is drawn cell by cell")
    func compositeKana() throws {
        var drawing = try makeDrawing("きゃ")
        #expect(drawing.pass.figure.cellCount == 2)
        #expect(drawing.pass.strokeCount == 7)
        try finish(&drawing)
        #expect(drawing.isPassed)
        #expect(drawing.mistakes == 0)
    }
}
