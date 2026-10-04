import SwiftUI
import UIKit

struct WritingTouchSurface: UIViewRepresentable {
    let onTouch: @MainActor (WritingTouch) -> Void

    func makeUIView(context: Context) -> WritingTouchView {
        let view = WritingTouchView()
        view.onTouch = onTouch
        view.accessibilityLabel = String(localized: "Writing area")
        return view
    }

    func updateUIView(_ view: WritingTouchView, context: Context) {
        view.onTouch = onTouch
    }
}

final class WritingTouchView: UIView {
    var onTouch: (@MainActor (WritingTouch) -> Void)?

    private weak var activeTouch: UITouch?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = false
        isExclusiveTouch = true
        isOpaque = false
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = .allowsDirectInteraction
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let touch = touches.first else { return }
        activeTouch = touch
        onTouch?(.began(unit(touch.location(in: self))))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        let samples = event?.coalescedTouches(for: touch) ?? [touch]
        onTouch?(.moved(samples.map { unit($0.location(in: self)) }))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        activeTouch = nil
        onTouch?(.ended(unit(touch.location(in: self))))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        activeTouch = nil
        onTouch?(.cancelled)
    }

    private func unit(_ point: CGPoint) -> CGPoint {
        let side = max(1, min(bounds.width, bounds.height))
        return CGPoint(x: point.x / side, y: point.y / side)
    }
}
