import Observation
import SwiftUI

struct TabHeaderConfig<ID: Hashable>: Identifiable {
    let id: ID
    let text: String
}

extension TabHeaderConfig: Sendable where ID: Sendable {}

enum AnimatedTabsMetrics {
    static let barHeight: CGFloat = 44
    static let barInnerPadding: CGFloat = 4
    static let tabFontSize: CGFloat = 15
    static let indicatorCornerRadius: CGFloat = 18

    static let releaseAnimation = Animation.timingCurve(
        0.2,
        0.82,
        0.22,
        1,
        duration: 0.34
    )
}

@MainActor
@Observable
final class AnimatedTabsLiveState {
    var position: CGFloat = 0
}
