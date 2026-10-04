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

struct WritingCanvas: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WritingServicesStore { .shared }
    private var interactions: WritingInteractionsStore { .shared }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

            ZStack {
                WritingGuides(centers: service.figure?.cellCenters ?? [0.5], side: side)
                WritingPhantomLayer(side: side)
                WritingDoneInkLayer(side: side)
                WritingLiveInkLayer(side: side)
                WritingMarkerLayer(side: side)
                WritingTouchSurface(onTouch: { interactions.handle($0) })
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

private struct WritingPhantomLayer: View {
    let side: CGFloat

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WritingServicesStore { .shared }

    var body: some View {
        let isFailed = service.failure != nil
        let showsWhole = service.stage.showsPhantom && service.phase != .written
        let showsCurrent = (service.stage.showsPhantom && service.phase == .writing) || isFailed

        ZStack {
            if let figure = service.figure {
                let width = WritingInk.lineWidth(side: side, figure: figure)
                if showsWhole {
                    WritingInk.path(figure.strokes, side: side)
                        .stroke(theme.text.primary.opacity(theme.isDark ? 0.14 : 0.09), style: WritingInk.style(width))
                        .transition(.opacity)
                }
                if showsCurrent, let stroke = service.currentStroke {
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

private struct WritingDoneInkLayer: View {
    let side: CGFloat

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WritingServicesStore { .shared }

    var body: some View {
        let isWritten = service.phase == .written

        ZStack {
            if let figure = service.figure {
                WritingInk.path(service.doneStrokes, side: side)
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

private struct WritingLiveInkLayer: View {
    let side: CGFloat

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WritingServicesStore { .shared }

    var body: some View {
        let isFailed = service.failure != nil

        ZStack {
            if let figure = service.figure, !service.ink.isEmpty {
                WritingInk.path(service.ink, side: side)
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

private struct WritingMarkerLayer: View {
    let side: CGFloat

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WritingServicesStore { .shared }

    var body: some View {
        let failure = service.failure
        let showsPoints = (service.stage.showsPoints && service.phase == .writing) || failure != nil

        ZStack {
            if let figure = service.figure {
                let diameter = WritingInk.markerDiameter(side: side, figure: figure)

                if showsPoints, let stroke = service.currentStroke, let start = stroke.first, let end = stroke.last {
                    WritingPointPair(
                        start: WritingInk.point(start, side: side),
                        end: WritingInk.point(end, side: side),
                        diameter: diameter,
                        isTouching: service.isTouching,
                        reachedEnd: service.reachedEnd
                    )
                    .id("\(service.passToken).\(service.strokeIndex)")
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
