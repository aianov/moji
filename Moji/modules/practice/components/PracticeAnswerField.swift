import SwiftUI
import UIKit

struct PracticeAnswerField: View {
    let model: PracticeQuestionModel
    let reveal: PracticeReveal?

    @Environment(\.scenePhase) private var scenePhase
    @State private var hasJapaneseKeyboard = PracticeKeyboards.hasJapanese

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: PracticeServicesStore { .shared }
    private var interactions: PracticeInteractionsStore { .shared }

    var body: some View {
        VStack(spacing: 8) {
            field

            if model.answerStyle == .character, !hasJapaneseKeyboard {
                Text("Add the Japanese keyboard: Settings › General › Keyboard › Keyboards › Add New Keyboard › Japanese")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.text.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            hasJapaneseKeyboard = PracticeKeyboards.hasJapanese
        }
    }

    private var field: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        return PracticeKeyboardTextField(
            questionID: model.id,
            hintRevision: service.hintRevision,
            text: reveal?.typed ?? service.typedAnswer,
            placeholder: model.fieldPlaceholder,
            answerStyle: model.answerStyle,
            wantsFocus: service.holdsKeyboard(model),
            isLocked: reveal != nil,
            returnKeyType: reveal == nil ? .done : .continue,
            textColor: UIColor(textColor),
            placeholderColor: UIColor(theme.text.secondary),
            onEdit: { interactions.editTypedAnswer($0, isComposing: $1) },
            onFocus: { interactions.focusAnswerField() },
            onReturn: { interactions.keyboardReturn() }
        )
        .padding(.horizontal, 44)
        .frame(height: 54)
        .background(shape.fill(theme.bg._300))
        .overlay(
            shape
                .strokeBorder(borderColor, lineWidth: reveal == nil ? 1 : 1.5)
                .allowsHitTesting(false)
        )
        .overlay(alignment: .trailing) {
            if let reveal {
                if reveal.typed != nil {
                    Image(systemName: reveal.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(reveal.isCorrect ? MojiTint.correct : MojiTint.wrong)
                        .padding(.trailing, 14)
                        .transition(.scale.combined(with: .opacity))
                }
            } else {
                Button {
                    interactions.useHint()
                } label: {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.text.secondary)
                        .frame(width: 44, height: 54)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(Text("Show the answer"))
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: reveal)
    }

    private var textColor: Color {
        guard let reveal else { return theme.text.primary }
        guard reveal.typed != nil else { return theme.text.secondary }
        return reveal.isCorrect ? MojiTint.correct : MojiTint.wrong
    }

    private var borderColor: Color {
        guard let reveal else { return theme.border._200.opacity(theme.isDark ? 1 : 0.55) }
        guard reveal.typed != nil else { return theme.border._200.opacity(theme.isDark ? 1 : 0.55) }
        return reveal.isCorrect ? MojiTint.correct : MojiTint.wrong
    }
}

private struct PracticeKeyboardTextField: UIViewRepresentable {
    let questionID: String
    let hintRevision: Int
    let text: String
    let placeholder: String
    let answerStyle: PracticeAnswerStyle
    let wantsFocus: Bool
    let isLocked: Bool
    let returnKeyType: UIReturnKeyType
    let textColor: UIColor
    let placeholderColor: UIColor
    let onEdit: (String, Bool) -> Void
    let onFocus: () -> Void
    let onReturn: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PracticeFocusingTextField {
        let field = PracticeFocusingTextField()
        field.delegate = context.coordinator
        field.onInput = { [weak coordinator = context.coordinator] field in
            coordinator?.report(field)
        }
        Self.apply(answerStyle, to: field)
        context.coordinator.questionID = questionID
        context.coordinator.hintRevision = hintRevision
        field.textAlignment = .center
        field.adjustsFontSizeToFitWidth = true
        field.minimumFontSize = 14
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.smartInsertDeleteType = .no
        field.inlinePredictionType = .no
        field.writingToolsBehavior = .none
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: PracticeFocusingTextField, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.isApplying = true
        defer { coordinator.isApplying = false }

        if coordinator.questionID != questionID {
            coordinator.questionID = questionID
            if field.isComposing {
                field.unmarkText()
            }
            if field.answerStyle != answerStyle {
                Self.apply(answerStyle, to: field)
                if field.isFirstResponder {
                    field.reloadInputViews()
                }
            }
            coordinator.hintRevision = hintRevision
            UIView.transition(with: field, duration: 0.22, options: .transitionCrossDissolve) {
                field.text = text
            }
        } else if coordinator.hintRevision != hintRevision {
            coordinator.hintRevision = hintRevision
            if field.isComposing {
                field.unmarkText()
            }
            field.text = text
        } else if isLocked, field.isComposing {
            field.unmarkText()
            field.text = text
        } else if field.text != text, !field.isComposing {
            field.text = text
        }
        if field.textColor != textColor {
            field.textColor = textColor
            field.tintColor = textColor
        }
        if field.placeholder != placeholder || context.coordinator.placeholderColor != placeholderColor {
            context.coordinator.placeholderColor = placeholderColor
            field.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: placeholderColor]
            )
        }
        if field.returnKeyType != returnKeyType {
            field.returnKeyType = returnKeyType
            if field.isFirstResponder {
                field.reloadInputViews()
            }
        }

        field.wantsFocus = wantsFocus
        if field.needsFocusChange {
            Task { @MainActor in
                field.applyFocus()
            }
        }
    }

    static func dismantleUIView(_ field: PracticeFocusingTextField, coordinator: Coordinator) {
        field.wantsFocus = false
    }

    private static func apply(_ style: PracticeAnswerStyle, to field: PracticeFocusingTextField) {
        field.answerStyle = style
        field.font = font(for: style)
        field.keyboardType = style == .romaji ? .asciiCapable : .default
    }

    private static func font(for style: PracticeAnswerStyle) -> UIFont {
        let system = UIFont.systemFont(ofSize: 22, weight: .semibold)
        guard style == .character else { return system }
        let japanese = UIFontDescriptor(name: "HiraginoSans-W6", size: 22)
        return UIFont(descriptor: system.fontDescriptor.addingAttributes([.cascadeList: [japanese]]), size: 22)
    }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PracticeKeyboardTextField
        var placeholderColor: UIColor?
        var questionID = ""
        var hintRevision = 0
        var isApplying = false

        init(parent: PracticeKeyboardTextField) {
            self.parent = parent
        }

        func report(_ field: PracticeFocusingTextField) {
            guard !isApplying else { return }
            parent.onEdit(field.text ?? "", field.isComposing)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onFocus()
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            (textField as? PracticeFocusingTextField)?.inputDidChange()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            guard let field = textField as? PracticeFocusingTextField else { return false }
            report(field)
            guard !field.isComposing, !field.justCommitted else { return false }
            parent.onReturn()
            return false
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            !parent.isLocked
        }
    }
}

private final class PracticeFocusingTextField: UITextField {
    var wantsFocus = false
    var answerStyle: PracticeAnswerStyle = .romaji
    var onInput: ((PracticeFocusingTextField) -> Void)?
    private(set) var justCommitted = false
    private var wasComposing = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(inputDidChange), for: .editingChanged)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidChange),
            name: UITextInputMode.currentInputModeDidChangeNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var textInputMode: UITextInputMode? {
        PracticeKeyboards.inputMode(for: answerStyle) ?? super.textInputMode
    }

    var isComposing: Bool {
        markedTextRange != nil
    }

    var needsFocusChange: Bool {
        window != nil && wantsFocus != isFirstResponder
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyFocus()
    }

    override func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        super.setMarkedText(markedText, selectedRange: selectedRange)
        inputDidChange()
    }

    override func unmarkText() {
        super.unmarkText()
        inputDidChange()
    }

    @objc func inputDidChange() {
        let composing = isComposing
        if wasComposing, !composing {
            justCommitted = true
            Task { @MainActor [weak self] in
                self?.justCommitted = false
            }
        }
        wasComposing = composing
        onInput?(self)
    }

    func applyFocus() {
        guard window != nil else { return }
        if wantsFocus, !isFirstResponder {
            becomeFirstResponder()
        } else if !wantsFocus, isFirstResponder {
            resignFirstResponder()
        }
    }

    @objc private func keyboardDidChange() {
        guard isFirstResponder else { return }
        PracticeKeyboards.remember(super.textInputMode, for: answerStyle)
    }
}

@MainActor
private enum PracticeKeyboards {
    private static var lastUsed: [PracticeAnswerStyle: UITextInputMode] = [:]

    static var japanese: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage?.hasPrefix("ja") == true }
    }

    static var hasJapanese: Bool {
        japanese != nil
    }

    static func inputMode(for style: PracticeAnswerStyle) -> UITextInputMode? {
        lastUsed[style] ?? (style == .character ? japanese : nil)
    }

    static func remember(_ mode: UITextInputMode?, for style: PracticeAnswerStyle) {
        guard let mode,
              let language = mode.primaryLanguage,
              language != "emoji",
              language != "dictation",
              style != .romaji || !language.hasPrefix("ja") else {
            return
        }
        lastUsed[style] = mode
    }
}
