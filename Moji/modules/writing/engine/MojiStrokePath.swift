import CoreGraphics
import Foundation

struct MojiPathProjection: Equatable, Sendable {
    let position: CGFloat
    let distance: CGFloat
}

struct MojiStrokePath: Equatable, Sendable {
    let points: [CGPoint]
    let distances: [CGFloat]

    init(_ points: [CGPoint]) {
        let points = points.isEmpty ? [CGPoint.zero] : points
        var distances: [CGFloat] = [0]
        distances.reserveCapacity(points.count)
        var running: CGFloat = 0
        for index in points.indices.dropFirst() {
            running += Self.distance(points[index - 1], points[index])
            distances.append(running)
        }
        self.points = points
        self.distances = distances
    }

    var length: CGFloat {
        distances[distances.count - 1]
    }

    var start: CGPoint {
        points[0]
    }

    var end: CGPoint {
        points[points.count - 1]
    }

    func point(at position: CGFloat) -> CGPoint {
        guard points.count > 1, position > 0 else { return start }
        guard position < length else { return end }
        let index = segment(containing: position)
        return interpolate(segment: index, at: position)
    }

    func prefix(through position: CGFloat) -> [CGPoint] {
        guard points.count > 1, position > 0 else { return [start] }
        guard position < length else { return points }
        let index = segment(containing: position)
        return Array(points[0...index]) + [interpolate(segment: index, at: position)]
    }

    func closest(to target: CGPoint, within range: ClosedRange<CGFloat>) -> MojiPathProjection {
        let lower = min(max(0, range.lowerBound), length)
        let upper = min(max(lower, range.upperBound), length)
        guard points.count > 1 else {
            return MojiPathProjection(position: 0, distance: Self.distance(start, target))
        }

        var best = MojiPathProjection(position: lower, distance: .infinity)
        for index in 0..<(points.count - 1) {
            let from = distances[index]
            let to = distances[index + 1]
            if to < lower { continue }
            if from > upper { break }

            let a = points[index]
            let b = points[index + 1]
            let span = to - from
            var t: CGFloat = 0
            if span > 0 {
                let dx = b.x - a.x
                let dy = b.y - a.y
                let along = ((target.x - a.x) * dx + (target.y - a.y) * dy) / (dx * dx + dy * dy)
                t = min(max(along, max(0, (lower - from) / span)), min(1, (upper - from) / span))
            }
            let candidate = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            let gap = Self.distance(candidate, target)
            if gap < best.distance {
                best = MojiPathProjection(position: from + span * t, distance: gap)
            }
        }
        return best
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func segment(containing position: CGFloat) -> Int {
        var low = 0
        var high = distances.count - 1
        while high - low > 1 {
            let middle = (low + high) / 2
            if distances[middle] <= position {
                low = middle
            } else {
                high = middle
            }
        }
        return low
    }

    private func interpolate(segment index: Int, at position: CGFloat) -> CGPoint {
        let a = points[index]
        let b = points[index + 1]
        let span = distances[index + 1] - distances[index]
        guard span > 0 else { return a }
        let t = (position - distances[index]) / span
        return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}
