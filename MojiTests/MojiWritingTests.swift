import CoreGraphics
import Foundation
import Testing
@testable import Moji

enum WritingFixture {
    static let library: MojiStrokeLibrary? = MojiStrokeLibrary.bundled() ?? MojiStrokeLibrary(url: sourceURL)

    static let missingOldForms: Set<String> = [
        "俠", "卽", "增", "寬", "巢", "徵", "德", "揭", "擊", "晚", "曆", "橫", "步", "歷", "每", "涉",
        "淚", "渴", "溫", "瀨", "狀", "瘦", "綠", "緖", "緣", "薰", "虛", "蠟", "賴", "郞", "錄", "鍊"
    ]

    private static var sourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Moji/Resources/Strokes/moji-strokes.dat")
    }

    static func figure(_ text: String) throws -> MojiWritingFigure {
        let library = try #require(library)
        return try #require(library.figure(for: text))
    }

    static func path(_ text: String, stroke: Int) throws -> MojiStrokePath {
        let figure = try figure(text)
        return try #require(figure.path(stroke))
    }

    static func finger(
        along path: MojiStrokePath,
        from start: CGFloat = 0,
        to end: CGFloat? = nil,
        wobble: CGFloat = 0,
        bias: CGFloat = 0,
        step: CGFloat = 0.01
    ) -> [CGPoint] {
        let last = min(end ?? path.length, path.length)
        var positions: [CGFloat] = []
        var position = start
        while position < last {
            positions.append(position)
            position += step
        }
        positions.append(last)
        return positions.map { position in
            let point = path.point(at: position)
            let ahead = path.point(at: min(path.length, position + 0.005))
            let behind = path.point(at: max(0, position - 0.005))
            let dx = ahead.x - behind.x
            let dy = ahead.y - behind.y
            let length = max(hypot(dx, dy), 0.000_001)
            let lateral = bias + wobble * sin(position / 0.12 * 2 * .pi)
            return CGPoint(x: point.x - dy / length * lateral, y: point.y + dx / length * lateral)
        }
    }

    static func line(from start: CGPoint, toward direction: CGPoint, distance: CGFloat, step: CGFloat = 0.01) -> [CGPoint] {
        let length = max(hypot(direction.x, direction.y), 0.000_001)
        var result: [CGPoint] = []
        var travelled = step
        while travelled <= distance {
            result.append(CGPoint(
                x: start.x + direction.x / length * travelled,
                y: start.y + direction.y / length * travelled
            ))
            travelled += step
        }
        return result
    }

    @discardableResult
    static func trace(_ tracer: inout MojiStrokeTracer, _ points: [CGPoint], lift: Bool = true) -> [MojiTraceEvent] {
        guard let first = points.first else { return [] }
        var events: [MojiTraceEvent] = []
        if let event = tracer.begin(at: first) {
            events.append(event)
        }
        for point in points.dropFirst() {
            if let event = tracer.move(to: point) {
                events.append(event)
            }
        }
        if lift, let event = tracer.end(at: points.last) {
            events.append(event)
        }
        return events
    }

    static func write(_ block: inout MojiWritingBlock) -> [MojiWritingEvent] {
        var events: [MojiWritingEvent] = []
        let figure = block.pass.figure
        for index in block.pass.strokeIndex..<figure.strokeCount {
            let points = finger(along: MojiStrokePath(figure.strokes[index]), wobble: 0.01)
            if let event = block.touchBegan(at: points[0]) {
                events.append(event)
            }
            for point in points.dropFirst() {
                if let event = block.touchMoved(to: point) {
                    events.append(event)
                }
            }
            if let event = block.touchEnded(at: points.last) {
                events.append(event)
            }
        }
        return events
    }

    static func failStroke(_ block: inout MojiWritingBlock) -> MojiWritingEvent? {
        guard let path = block.pass.currentPath else { return nil }
        let wrong = CGPoint(x: path.start.x + 0.3, y: path.start.y)
        let point = wrong.x > 0.95 ? CGPoint(x: path.start.x - 0.3, y: path.start.y) : wrong
        return block.touchBegan(at: point)
    }
}

@Suite("Stroke data")
struct MojiStrokeDataTests {
    @Test("Every kana item and every kanji with a KanjiVG drawing can be written")
    func coverage() throws {
        let library = try #require(WritingFixture.library)
        let catalog = MojiAlphabetCatalog.shared

        let kana = catalog.characters(.hiragana) + catalog.characters(.katakana)
        let unwritableKana = kana.filter { !library.canWrite($0.glyph) }.map(\.glyph)
        #expect(unwritableKana.isEmpty, "No strokes for \(unwritableKana)")

        let kanji = catalog.characters(.kanji)
        let unwritableKanji = Set(kanji.filter { !library.canWrite($0.glyph) }.map(\.glyph))
        #expect(unwritableKanji == WritingFixture.missingOldForms)
        #expect(kanji.count - unwritableKanji.count == 2910)
        #expect(library.count == 3061)
    }

    @Test("Strokes come in KanjiVG order, from the start of each stroke to its end")
    func realCharacters() throws {
        let library = try #require(WritingFixture.library)

        let sun = try #require(library.glyph("日"))
        #expect(sun.strokes.count == 4)
        let left = sun.strokes[0]
        #expect(abs(left[0].x - 31.5) < 0.1 && abs(left[0].y - 24.5) < 0.1)
        #expect(left.last!.y - left[0].y > 60)
        let frame = sun.strokes[1]
        #expect(frame.contains { $0.x > 75 && $0.y < 35 })
        #expect(frame.last!.x > 75 && frame.last!.y > 85)
        for bar in sun.strokes[2...] {
            #expect(bar.last!.x - bar[0].x > 40)
        }

        let one = try #require(library.glyph("一"))
        #expect(one.strokes.count == 1)
        #expect(one.strokes[0].last!.x - one.strokes[0][0].x > 80)

        let ten = try #require(library.glyph("十"))
        #expect(ten.strokes.count == 2)
        #expect(ten.strokes[0].last!.x > ten.strokes[0][0].x)
        #expect(ten.strokes[1].last!.y > ten.strokes[1][0].y)

        #expect(library.glyph("永")?.strokes.count == 5)
        #expect(library.glyph("あ")?.strokes.count == 3)
        #expect(library.glyph("鬱")?.strokes.count == 29)

        let pa = try #require(library.glyph("ぱ"))
        #expect(pa.strokes.count == 4)
        let circle = MojiStrokePath(pa.strokes[3])
        #expect(MojiStrokePath.distance(circle.start, circle.end) < 0.5)
        #expect(circle.length > 30)

        let bar = try #require(library.glyph("ー"))
        #expect(bar.strokes.count == 1)
        #expect(bar.strokes[0].last!.x - bar.strokes[0][0].x > 70)

        let n = try #require(library.glyph("ン"))
        #expect(n.strokes.count == 2)
        #expect(n.strokes[1].last!.y < n.strokes[1][0].y)
    }

    @Test("Every point stays inside the KanjiVG box")
    func pointsInsideTheBox() throws {
        let library = try #require(WritingFixture.library)
        for scalar in library.scalars {
            let glyph = try #require(library.glyph(scalar))
            #expect(!glyph.strokes.isEmpty)
            for stroke in glyph.strokes {
                #expect(stroke.count >= 2)
                #expect(stroke.allSatisfy { (0...MojiStrokeLibrary.gridSize).contains($0.x) && (0...MojiStrokeLibrary.gridSize).contains($0.y) })
            }
        }
    }

    @Test("A file that is not a stroke file is refused")
    func refusesForeignData() {
        #expect(MojiStrokeLibrary(data: Data("MJSX".utf8) + Data(count: 32)) == nil)
        #expect(MojiStrokeLibrary(data: Data()) == nil)
    }

    @Test("A kana pair is laid out as a row of cells written one after another")
    func compositeRow() throws {
        let pair = try WritingFixture.figure("きゃ")
        let ki = try WritingFixture.figure("き")
        #expect(pair.cellCount == 2)
        #expect(pair.strokeCount == 7)
        #expect(pair.cellCenters.count == 2)
        #expect(pair.glyphScale < 1)

        let all = pair.strokes.flatMap { $0 }
        #expect(all.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })

        let kiRight = pair.strokes[0..<4].flatMap { $0 }.map(\.x).max()!
        let yaLeft = pair.strokes[4...].flatMap { $0 }.map(\.x).min()!
        #expect(yaLeft > kiRight)

        let kiHeight = ki.strokes.flatMap { $0 }.map(\.y)
        let yaHeight = pair.strokes[4...].flatMap { $0 }.map(\.y)
        #expect(yaHeight.max()! - yaHeight.min()! < (kiHeight.max()! - kiHeight.min()!) * pair.glyphScale)

        let long = try WritingFixture.figure("アー")
        #expect(long.strokeCount == 3)
        #expect(try WritingFixture.figure("っか").strokeCount == 4)
    }

    @Test("A single character fills the canvas inside its margin")
    func singleCell() throws {
        let figure = try WritingFixture.figure("永")
        #expect(figure.cellCount == 1)
        #expect(figure.glyphScale == 1)
        let all = figure.strokes.flatMap { $0 }
        #expect(all.allSatisfy { (MojiWritingLayout.margin...(1 - MojiWritingLayout.margin)).contains($0.x) })
        #expect(all.allSatisfy { (MojiWritingLayout.margin...(1 - MojiWritingLayout.margin)).contains($0.y) })
    }
}

@Suite("Stroke tracing")
struct MojiStrokeTracingTests {
    @Test("A wobbly finger that stays near the line draws the stroke", arguments: [
        ("日", 1), ("口", 1), ("一", 0), ("あ", 2), ("ぬ", 1), ("ん", 0), ("ぱ", 3), ("永", 1)
    ])
    func onLine(text: String, stroke: Int) throws {
        let path = try WritingFixture.path(text, stroke: stroke)
        var tracer = MojiStrokeTracer(path: path)
        let points = WritingFixture.finger(along: path, wobble: 0.03, bias: 0.025)
        let events = WritingFixture.trace(&tracer, points)

        #expect(events.contains(.reachedEnd))
        #expect(events.last == .completed)
        #expect(tracer.phase == .completed)
        #expect(tracer.ink == path.points)
    }

    @Test("Leaving the line fails at once")
    func offLine() throws {
        let path = try WritingFixture.path("日", stroke: 0)
        var tracer = MojiStrokeTracer(path: path)
        let half = WritingFixture.finger(along: path, to: path.length / 2)
        let away = WritingFixture.line(from: half.last!, toward: CGPoint(x: 1, y: 0), distance: 0.2)
        let events = WritingFixture.trace(&tracer, half + away, lift: false)

        #expect(events.last == .failed(.offLine))
        #expect(tracer.phase == .failed(.offLine))
        #expect(tracer.move(to: path.end) == nil)
    }

    @Test("Starting away from point A fails")
    func wrongStart() throws {
        let path = try WritingFixture.path("十", stroke: 0)
        var tracer = MojiStrokeTracer(path: path)
        let start = CGPoint(x: path.start.x, y: path.start.y + MojiTraceTolerance.standard.startRadius * 1.3)
        #expect(tracer.begin(at: start) == .failed(.wrongStart))
        #expect(tracer.touchDown == start)

        var near = MojiStrokeTracer(path: path)
        let close = CGPoint(x: path.start.x, y: path.start.y + MojiTraceTolerance.standard.startRadius * 0.7)
        #expect(near.begin(at: close) == .began)
    }

    @Test("A stroke drawn the wrong way fails")
    func wrongDirection() throws {
        let path = try WritingFixture.path("一", stroke: 0)
        var reversed = MojiStrokeTracer(path: path)
        let events = WritingFixture.trace(&reversed, WritingFixture.finger(along: path).reversed())
        #expect(events == [.failed(.wrongStart)])

        var turned = MojiStrokeTracer(path: path)
        let forward = WritingFixture.finger(along: path, to: path.length * 0.7)
        let back = Array(WritingFixture.finger(along: path, from: path.length * 0.1, to: path.length * 0.7).reversed())
        let turnedEvents = WritingFixture.trace(&turned, forward + back, lift: false)
        #expect(turnedEvents.last == .failed(.backwards))
    }

    @Test("Lifting the finger before point B fails, a tap on A does nothing")
    func liftedEarly() throws {
        let path = try WritingFixture.path("口", stroke: 1)
        let corner = path.points.enumerated().max { $0.element.x - $0.element.y < $1.element.x - $1.element.y }!.offset
        var tracer = MojiStrokeTracer(path: path)
        let events = WritingFixture.trace(&tracer, WritingFixture.finger(along: path, to: path.distances[corner]))
        #expect(events.last == .failed(.liftedEarly))

        var tapped = MojiStrokeTracer(path: path)
        #expect(tapped.begin(at: path.start) == .began)
        #expect(tapped.end(at: path.start) == nil)
        #expect(tapped.phase == .waiting)
        #expect(tapped.begin(at: path.start) == .began)
    }

    @Test("Going past point B after reaching it still counts")
    func overshoot() throws {
        let path = try WritingFixture.path("一", stroke: 0)
        var tracer = MojiStrokeTracer(path: path)
        let points = WritingFixture.finger(along: path)
        let beyond = WritingFixture.line(from: path.end, toward: CGPoint(x: 1, y: 0.3), distance: 0.15)
        let events = WritingFixture.trace(&tracer, points + beyond)
        #expect(events.last == .completed)
    }

    @Test("The ink follows the reference stroke, not the finger")
    func inkSnapsToTheStroke() throws {
        let path = try WritingFixture.path("ぬ", stroke: 1)
        var tracer = MojiStrokeTracer(path: path)
        let points = WritingFixture.finger(along: path, to: path.length * 0.5, wobble: 0.02, bias: 0.04)
        WritingFixture.trace(&tracer, points, lift: false)

        #expect(tracer.phase == .tracing)
        #expect(tracer.fraction > 0.4 && tracer.fraction < 0.6)
        let ink = tracer.ink
        #expect(ink.count >= 2)
        for point in ink {
            #expect(path.closest(to: point, within: 0...path.length).distance < 0.0001)
        }
        #expect(MojiStrokePath.distance(ink.last!, path.point(at: tracer.progress)) < 0.0001)
    }

    @Test("A small closed loop starts and ends on the same point")
    func loop() throws {
        let path = try WritingFixture.path("ぱ", stroke: 3)
        var tapped = MojiStrokeTracer(path: path)
        WritingFixture.trace(&tapped, [path.start, CGPoint(x: path.start.x + 0.005, y: path.start.y)])
        #expect(tapped.phase == .waiting)

        var tracer = MojiStrokeTracer(path: path)
        let events = WritingFixture.trace(&tracer, WritingFixture.finger(along: path, wobble: 0.02))
        #expect(events.last == .completed)
    }

    @Test("A dot is done as soon as the finger lands on it")
    func dot() throws {
        let path = try WritingFixture.path("永", stroke: 0)
        var tracer = MojiStrokeTracer(path: path)
        #expect(tracer.begin(at: path.point(at: path.length / 2)) == .reachedEnd)
        #expect(tracer.end(at: nil) == .completed)
    }

    @Test("Memory stage gives the finger more room than tracing")
    func memoryIsWider() {
        let base = MojiTraceTolerance.standard
        let wide = base.widened(by: MojiWritingStage.memory.toleranceFactor)
        #expect(wide.corridor > base.corridor)
        #expect(wide.startRadius > base.startRadius)
        #expect(MojiWritingStage.phantom.toleranceFactor == 1)
        #expect(MojiWritingStage.points.toleranceFactor == 1)
    }

    @Test("A normal finger draws every stroke of every character", arguments: 0..<8)
    func everyStroke(share: Int) throws {
        let library = try #require(WritingFixture.library)
        var failures: [String] = []
        for (index, scalar) in library.scalars.enumerated() where index % 8 == share {
            let figure = try #require(library.figure(for: String(Character(scalar))))
            for (index, stroke) in figure.strokes.enumerated() {
                let path = MojiStrokePath(stroke)
                var tracer = MojiStrokeTracer(path: path)
                let events = WritingFixture.trace(
                    &tracer,
                    WritingFixture.finger(along: path, wobble: 0.025, bias: 0.02, step: 0.012)
                )
                if events.last != .completed {
                    failures.append("\(Character(scalar)) \(index + 1)")
                }
            }
        }
        #expect(failures.isEmpty, "\(failures.prefix(20))")
    }
}

@Suite("Writing stages")
struct MojiWritingStageTests {
    private func card(_ text: String) throws -> MojiWritingCard {
        MojiWritingCard(id: text, figure: try WritingFixture.figure(text))
    }

    @Test("Stage 1 shows the phantom and points, stage 2 only points, stage 3 nothing")
    func visibility() {
        #expect(MojiWritingStage.phantom.showsPhantom && MojiWritingStage.phantom.showsPoints)
        #expect(!MojiWritingStage.points.showsPhantom && MojiWritingStage.points.showsPoints)
        #expect(!MojiWritingStage.memory.showsPhantom && !MojiWritingStage.memory.showsPoints)
    }

    @Test("Passing climbs a stage, stage 3 finishes the character")
    func climbing() throws {
        var card = try card("日")
        #expect(card.stage == .phantom)
        #expect(card.writingsLeft == 3)
        #expect(card.pass() == .stageUp(.points))
        #expect(card.writingsLeft == 2)
        #expect(card.pass() == .stageUp(.memory))
        #expect(card.writingsLeft == 1)
        #expect(card.pass() == .finished)
        #expect(card.isFinished)
        #expect(card.writingsLeft == 0)
        #expect(card.writings == 3)
    }

    @Test("A failure drops one stage, at stage 1 only the stroke starts over")
    func falling() throws {
        var card = try card("日")
        card.pass()
        card.pass()
        #expect(card.fail() == .stageDown(.points))
        #expect(card.writingsLeft == 2)
        #expect(card.fail() == .stageDown(.phantom))
        #expect(card.fail() == .strokeAgain)
        #expect(card.stage == .phantom)
        #expect(card.mistakes == 3)
        #expect(card.writingsLeft == 3)
    }

    @Test("Five kanji without a mistake take exactly fifteen writings, round by round")
    func fifteenWritings() throws {
        let texts = ["日", "月", "火", "水", "木"]
        var block = try #require(MojiWritingBlock(cards: try texts.map(card)))
        #expect(block.writingsLeft == 15)

        var order: [String] = []
        var writings = 0
        while !block.isFinished, writings < 40 {
            order.append("\(block.card.id)\(block.pass.stage.number)")
            let events = WritingFixture.write(&block)
            #expect(events.last == .written)
            #expect(block.phase == .written)
            writings += 1
            block.advance()
        }

        #expect(writings == 15)
        #expect(block.writingsLeft == 0)
        #expect(block.writingsDone == 15)
        #expect(block.mistakes == 0)
        #expect(Array(order.prefix(5)) == texts.map { "\($0)1" })
        #expect(Array(order[5..<10]) == texts.map { "\($0)2" })
        #expect(Array(order.suffix(5)) == texts.map { "\($0)3" })
    }

    @Test("A mistake at stage 3 means writing the character again from stage 2")
    func mistakeCostsMore() throws {
        var block = try #require(MojiWritingBlock(cards: [try card("口")]))
        _ = WritingFixture.write(&block)
        block.advance()
        _ = WritingFixture.write(&block)
        block.advance()
        #expect(block.pass.stage == .memory)
        #expect(block.writingsLeft == 1)

        #expect(WritingFixture.failStroke(&block) == .failed(.wrongStart, stroke: 0))
        #expect(block.phase == .failed(.wrongStart))
        #expect(block.verdict == .stageDown(.points))
        #expect(block.writingsLeft == 2)
        #expect(block.touchBegan(at: block.pass.currentPath!.start) == nil)

        block.advance()
        #expect(block.phase == .writing)
        #expect(block.pass.stage == .points)
        #expect(block.pass.strokeIndex == 0)

        _ = WritingFixture.write(&block)
        block.advance()
        #expect(block.pass.stage == .memory)
        _ = WritingFixture.write(&block)
        block.advance()
        #expect(block.isFinished)
        #expect(block.writingsDone == 4)
        #expect(block.mistakes == 1)
    }

    @Test("At stage 1 a failed stroke is drawn again, the strokes before it stay")
    func strokeRestartsAtStageOne() throws {
        var block = try #require(MojiWritingBlock(cards: [try card("日")]))
        let first = MojiStrokePath(block.pass.figure.strokes[0])
        let points = WritingFixture.finger(along: first)
        _ = block.touchBegan(at: points[0])
        for point in points.dropFirst() {
            _ = block.touchMoved(to: point)
        }
        #expect(block.touchEnded(at: points.last) == .strokeDone(stroke: 0))
        #expect(block.pass.strokeIndex == 1)

        #expect(WritingFixture.failStroke(&block) == .failed(.wrongStart, stroke: 1))
        #expect(block.verdict == .strokeAgain)
        #expect(block.writingsLeft == 3)
        block.advance()
        #expect(block.pass.stage == .phantom)
        #expect(block.pass.strokeIndex == 1)
        #expect(block.pass.tracer?.phase == .waiting)

        let events = WritingFixture.write(&block)
        #expect(events.last == .written)
        #expect(block.card.stage == .points)
    }

    @Test("Strokes are written in order and each one hands over to the next")
    func strokeOrder() throws {
        var pass = MojiWritingPass(figure: try WritingFixture.figure("十"), stage: .points)
        #expect(pass.strokeCount == 2)
        let second = MojiStrokePath(pass.figure.strokes[1])
        #expect(pass.begin(at: second.start) == .failed(.wrongStart, stroke: 0))

        var fresh = MojiWritingPass(figure: try WritingFixture.figure("十"), stage: .points)
        let first = MojiStrokePath(fresh.figure.strokes[0])
        let points = WritingFixture.finger(along: first)
        _ = fresh.begin(at: points[0])
        for point in points.dropFirst() {
            _ = fresh.move(to: point)
        }
        #expect(fresh.end(at: points.last) == .strokeDone(stroke: 0))
        #expect(fresh.doneStrokes.count == 1)
        #expect(fresh.currentPath?.start == second.start)
    }

    @Test("An empty block cannot start")
    func emptyBlock() {
        #expect(MojiWritingBlock(cards: []) == nil)
    }
}
