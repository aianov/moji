import SwiftUI

struct LearnKanjiGrid: Layout {
    var minimumCellWidth: CGFloat = 84
    var maximumColumns = 3
    var spacing: CGFloat = 4
    var rowSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? idealWidth
        let heights = rowHeights(of: subviews, width: width)
        let gaps = rowSpacing * CGFloat(max(0, heights.count - 1))
        return CGSize(width: width, height: heights.reduce(0, +) + gaps)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = columns(for: bounds.width)
        let cell = cellWidth(for: bounds.width, columns: columns)
        var y = bounds.minY
        for (row, height) in rowHeights(of: subviews, width: bounds.width).enumerated() {
            for column in 0..<columns {
                let index = row * columns + column
                guard subviews.indices.contains(index) else { break }
                subviews[index].place(
                    at: CGPoint(x: bounds.minX + CGFloat(column) * (cell + spacing), y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: cell, height: height)
                )
            }
            y += height + rowSpacing
        }
    }

    private var idealWidth: CGFloat {
        CGFloat(maximumColumns) * minimumCellWidth + CGFloat(maximumColumns - 1) * spacing
    }

    private func columns(for width: CGFloat) -> Int {
        let fitting = ((width + spacing) / (minimumCellWidth + spacing)).rounded(.down)
        return max(1, min(maximumColumns, Int(max(0, fitting))))
    }

    private func cellWidth(for width: CGFloat, columns: Int) -> CGFloat {
        max(0, (width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
    }

    private func rowHeights(of subviews: Subviews, width: CGFloat) -> [CGFloat] {
        let columns = columns(for: width)
        let cell = cellWidth(for: width, columns: columns)
        return stride(from: 0, to: subviews.count, by: columns).map { start in
            subviews[start..<min(start + columns, subviews.count)]
                .map { $0.sizeThatFits(ProposedViewSize(width: cell, height: nil)).height }
                .max() ?? 0
        }
    }
}
