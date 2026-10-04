import SwiftUI
import UIKit

struct NoteBodyTextView: UIViewRepresentable {
    static let fontSize: CGFloat = 17
    static let horizontalInset: CGFloat = 16
    static let topInset: CGFloat = 10
    static let bottomInset: CGFloat = 48

    let text: String
    let focusRequest: Int
    let textColor: UIColor
    let onEdit: (String) -> Void
    let onEditingChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.font = Self.font()
        view.adjustsFontForContentSizeCategory = true
        view.textColor = textColor
        view.tintColor = textColor
        view.text = text
        view.textContainerInset = UIEdgeInsets(
            top: Self.topInset,
            left: Self.horizontalInset,
            bottom: Self.bottomInset,
            right: Self.horizontalInset
        )
        view.textContainer.lineFragmentPadding = 0
        view.alwaysBounceVertical = true
        view.keyboardDismissMode = .interactive
        view.isFindInteractionEnabled = true
        view.autocapitalizationType = .sentences
        view.accessibilityLabel = String(localized: "Note text")
        context.coordinator.color = textColor
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        let isComposing = view.markedTextRange != nil

        if !isComposing, view.text != text {
            view.text = text
        }
        if !isComposing, coordinator.color != textColor {
            coordinator.color = textColor
            view.textColor = textColor
            view.tintColor = textColor
        }
        if coordinator.focusRequest != focusRequest {
            coordinator.focusRequest = focusRequest
            Task { @MainActor in
                _ = view.becomeFirstResponder()
            }
        }
    }

    private static func font() -> UIFont {
        let system = UIFont.systemFont(ofSize: fontSize, weight: .regular)
        let japanese = UIFontDescriptor(name: "HiraginoSans-W3", size: fontSize)
        let cascaded = UIFont(
            descriptor: system.fontDescriptor.addingAttributes([.cascadeList: [japanese]]),
            size: fontSize
        )
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: cascaded)
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NoteBodyTextView
        var focusRequest: Int
        var color: UIColor?

        init(parent: NoteBodyTextView) {
            self.parent = parent
            self.focusRequest = parent.focusRequest
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.onEdit(textView.text ?? "")
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onEditingChanged(true)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onEditingChanged(false)
        }
    }
}
