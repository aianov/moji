import CoreGraphics
import Foundation

struct MojiWritingFigure: Equatable, Sendable {
    let strokes: [[CGPoint]]
    let cellCount: Int
    let glyphScale: CGFloat
    let cellCenters: [CGFloat]

    var strokeCount: Int {
        strokes.count
    }

    func strokes(side: CGFloat) -> [[CGPoint]] {
        strokes.map { stroke in
            stroke.map { CGPoint(x: $0.x * side, y: $0.y * side) }
        }
    }

    func path(_ index: Int, side: CGFloat = 1) -> MojiStrokePath? {
        guard strokes.indices.contains(index) else { return nil }
        return MojiStrokePath(strokes[index].map { CGPoint(x: $0.x * side, y: $0.y * side) })
    }
}

enum MojiWritingLayout {
    static let margin: CGFloat = 0.03
    static let cellGap: CGFloat = 12

    static func figure(_ glyphs: [MojiStrokeGlyph]) -> MojiWritingFigure? {
        guard !glyphs.isEmpty, glyphs.allSatisfy({ !$0.strokes.isEmpty }) else { return nil }
        let grid = MojiStrokeLibrary.gridSize
        let usable = 1 - 2 * margin

        if glyphs.count == 1 {
            let scale = usable / grid
            return MojiWritingFigure(
                strokes: glyphs[0].strokes.map { stroke in
                    stroke.map { CGPoint(x: margin + $0.x * scale, y: margin + $0.y * scale) }
                },
                cellCount: 1,
                glyphScale: 1,
                cellCenters: [0.5]
            )
        }

        var shifts: [CGFloat] = []
        var middles: [CGFloat] = []
        var cursor: CGFloat = 0
        for glyph in glyphs {
            let xs = glyph.strokes.flatMap { $0.map(\.x) }
            let left = xs.min() ?? 0
            let right = xs.max() ?? grid
            shifts.append(cursor - left)
            middles.append(cursor + (right - left) / 2)
            cursor += right - left + cellGap
        }
        let width = cursor - cellGap
        let span = max(width, grid)
        let scale = usable / span
        let originX = (1 - width * scale) / 2
        let originY = (1 - grid * scale) / 2

        var strokes: [[CGPoint]] = []
        for (glyph, shift) in zip(glyphs, shifts) {
            for stroke in glyph.strokes {
                strokes.append(stroke.map { CGPoint(x: originX + ($0.x + shift) * scale, y: originY + $0.y * scale) })
            }
        }
        return MojiWritingFigure(
            strokes: strokes,
            cellCount: glyphs.count,
            glyphScale: grid / span,
            cellCenters: middles.map { originX + $0 * scale }
        )
    }
}
