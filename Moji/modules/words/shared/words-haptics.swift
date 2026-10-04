import UIKit

@MainActor
enum WordsHaptics {
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let notification = UINotificationFeedbackGenerator()

    static func flip() {
        soft.impactOccurred(intensity: 0.9)
        soft.prepare()
    }

    static func grade(_ button: MojiWordButton) {
        switch button {
        case .again:
            rigid.impactOccurred(intensity: 0.8)
            rigid.prepare()
        case .hard:
            light.impactOccurred()
            light.prepare()
        case .good:
            medium.impactOccurred(intensity: 0.85)
            medium.prepare()
        case .easy:
            notification.notificationOccurred(.success)
            notification.prepare()
        }
    }

    static func prepare() {
        soft.prepare()
        medium.prepare()
        rigid.prepare()
    }
}
