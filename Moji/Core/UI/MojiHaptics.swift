import UIKit

@MainActor
enum MojiHaptics {
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static let impactGenerator = UIImpactFeedbackGenerator(style: .soft)

    static func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    static func success() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    static func error() {
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }

    static func impact() {
        impactGenerator.impactOccurred()
        impactGenerator.prepare()
    }
}
