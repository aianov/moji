import SwiftUI

enum WritingInk {
    static let widthShare: CGFloat = 0.023
    static let markerShare: CGFloat = 0.044
    static let minimumWidth: CGFloat = 4

    static func lineWidth(side: CGFloat, figure: MojiWritingFigure) -> CGFloat {
        max(minimumWidth, side * widthShare * figure.glyphScale)
    }

    static func markerDiameter(side: CGFloat, figure: MojiWritingFigure) -> CGFloat {
        max(10, side * markerShare * max(0.8, figure.glyphScale))
    }

    static func style(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }

    static func path(_ strokes: [[CGPoint]], side: CGFloat) -> Path {
        var path = Path()
        for stroke in strokes {
            add(stroke, to: &path, side: side)
        }
        return path
    }

    static func path(_ stroke: [CGPoint], side: CGFloat) -> Path {
        var path = Path()
        add(stroke, to: &path, side: side)
        return path
    }

    static func point(_ point: CGPoint, side: CGFloat) -> CGPoint {
        CGPoint(x: point.x * side, y: point.y * side)
    }

    private static func add(_ stroke: [CGPoint], to path: inout Path, side: CGFloat) {
        guard let first = stroke.first else { return }
        path.move(to: point(first, side: side))
        guard stroke.count > 1 else {
            path.addLine(to: point(first, side: side))
            return
        }
        for next in stroke.dropFirst() {
            path.addLine(to: point(next, side: side))
        }
    }
}

@MainActor
protocol WritingCanvasSource: AnyObject {
    var figure: MojiWritingFigure? { get }
    var strokeIndex: Int { get }
    var currentStroke: [CGPoint]? { get }
    var doneStrokes: [[CGPoint]] { get }
    var ink: [CGPoint] { get }
    var isTouching: Bool { get }
    var reachedEnd: Bool { get }
    var resumePoint: CGPoint? { get }
    var failure: WritingFailure? { get }
    var passToken: Int { get }
    var showsWholePhantom: Bool { get }
    var showsCurrentStroke: Bool { get }
    var showsPoints: Bool { get }
    var isWritten: Bool { get }
}

struct WritingCanvas<Source: WritingCanvasSource>: View {
    let source: Source
    let onTouch: @MainActor (WritingTouch) -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

            ZStack {
                WritingGuides(centers: source.figure?.cellCenters ?? [0.5], side: side)
                WritingPhantomLayer(source: source, side: side)
                WritingDoneInkLayer(source: source, side: side)
                WritingLiveInkLayer(source: source, side: side)
                WritingMarkerLayer(source: source, side: side)
                WritingTouchSurface(onTouch: onTouch)
            }
            .frame(width: side, height: side)
            .background(shape.fill(theme.bg._300))
            .overlay(shape.strokeBorder(theme.border._200.opacity(theme.isDark ? 1 : 0.6), lineWidth: 1))
            .clipShape(shape)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct WritingGuides: View {
    let centers: [CGFloat]
    let side: CGFloat

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        Path { path in
            let inset: CGFloat = 12
            for center in centers {
                path.move(to: CGPoint(x: center * side, y: inset))
                path.addLine(to: CGPoint(x: center * side, y: side - inset))
            }
            path.move(to: CGPoint(x: inset, y: side / 2))
            path.addLine(to: CGPoint(x: side - inset, y: side / 2))
        }
        .stroke(
            theme.border._200.opacity(theme.isDark ? 0.9 : 0.7),
            style: StrokeStyle(lineWidth: 1, dash: [5, 6])
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct WritingPhantomLayer<Source: WritingCanvasSource>: View {
    let source: Source
    let side: CGFloat

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let showsWhole = source.showsWholePhantom
        let showsCurrent = source.showsCurrentStroke

        ZStack {
            if let figure = source.figure {
                let width = WritingInk.lineWidth(side: side, figure: figure)
                if showsWhole {
                    WritingInk.path(figure.strokes, side: side)
                        .stroke(theme.text.primary.opacity(theme.isDark ? 0.14 : 0.09), style: WritingInk.style(width))
                        .transition(.opacity)
                }
                if showsCurrent, let stroke = source.currentStroke {
                    WritingInk.path(stroke, side: side)
                        .stroke(theme.text.primary.opacity(theme.isDark ? 0.26 : 0.17), style: WritingInk.style(width))
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeOut(duration: 0.25), value: showsWhole)
        .animation(.easeOut(duration: 0.2), value: showsCurrent)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct WritingDoneInkLayer<Source: WritingCanvasSource>: View {
    let source: Source
    let side: CGFloat

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let isWritten = source.isWritten

        ZStack {
            if let figure = source.figure {
                WritingInk.path(source.doneStrokes, side: side)
                    .stroke(
                        isWritten ? MojiTint.correct : theme.text.primary,
                        style: WritingInk.style(WritingInk.lineWidth(side: side, figure: figure))
                    )
            }
        }
        .animation(.easeOut(duration: 0.25), value: isWritten)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct WritingLiveInkLayer<Source: WritingCanvasSource>: View {
    let source: Source
    let side: CGFloat

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let isFailed = source.failure != nil

        ZStack {
            if let figure = source.figure, !source.ink.isEmpty {
                WritingInk.path(source.ink, side: side)
                    .stroke(
                        isFailed ? MojiTint.wrong : theme.text.primary,
                        style: WritingInk.style(WritingInk.lineWidth(side: side, figure: figure))
                    )
            }
        }
        .animation(.easeOut(duration: 0.15), value: isFailed)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct WritingMarkerLayer<Source: WritingCanvasSource>: View {
    let source: Source
    let side: CGFloat

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let failure = source.failure
        let showsPoints = source.showsPoints

        ZStack {
            if let figure = source.figure {
                let diameter = WritingInk.markerDiameter(side: side, figure: figure)

                if showsPoints, let stroke = source.currentStroke, let start = stroke.first, let end = stroke.last {
                    WritingPointPair(
                        start: WritingInk.point(source.resumePoint ?? start, side: side),
                        end: WritingInk.point(end, side: side),
                        diameter: diameter,
                        isTouching: source.isTouching,
                        reachedEnd: source.reachedEnd
                    )
                    .id("\(source.passToken).\(source.strokeIndex)")
                }

                if let failure, failure.reason == .wrongStart, let touch = failure.touch {
                    Circle()
                        .strokeBorder(MojiTint.wrong, lineWidth: 2)
                        .frame(width: diameter * 1.6, height: diameter * 1.6)
                        .position(WritingInk.point(touch, side: side))
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: failure)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct WritingPointPair: View {
    let start: CGPoint
    let end: CGPoint
    let diameter: CGFloat
    let isTouching: Bool
    let reachedEnd: Bool

    @State private var showsStart = false
    @State private var showsEnd = false
    @State private var pulses = false

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let ring = diameter * 1.3

        ZStack {
            Circle()
                .fill(reachedEnd ? theme.text.primary : theme.bg._300)
                .overlay(Circle().strokeBorder(theme.text.primary.opacity(0.8), lineWidth: max(1.5, diameter * 0.15)))
                .frame(width: ring, height: ring)
                .scaleEffect(showsEnd ? (reachedEnd ? 1.12 : 1) : 0.3)
                .opacity(showsEnd ? 1 : 0)
                .position(end)

            ZStack {
                Circle()
                    .stroke(theme.text.primary.opacity(0.4), lineWidth: 1.5)
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(pulses ? 2.6 : 1)
                    .opacity(pulses ? 0 : 0.9)
                    .opacity(isTouching || reachedEnd ? 0 : 1)

                Circle()
                    .fill(theme.text.primary)
                    .frame(width: diameter, height: diameter)
            }
            .scaleEffect(showsStart ? 1 : 0.3)
            .opacity(showsStart ? 1 : 0)
            .position(start)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: reachedEnd)
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                showsStart = true
            }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.7).delay(0.22)) {
                showsEnd = true
            }
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false).delay(0.45)) {
                pulses = true
            }
        }
    }
}
