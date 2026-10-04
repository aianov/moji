import SwiftUI
import UIKit

struct CharacterSearchField: View {
    static let height: CGFloat = 44

    static func scrollAnchor(isEditing: Bool) -> UnitPoint {
        isEditing ? UnitPoint(x: 0.5, y: 0.1) : .center
    }

    let surface: CharacterSearchSurface
    let script: MojiScript

    @State private var focusRequest = 0

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: SearchServicesStore { .shared }
    private var interactions: SearchInteractionsStore { .shared }

    var body: some View {
        let state = service.state(surface)
        let isActive = service.activeScript(surface) == script
        let hasQuery = !state.query.isEmpty

        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.text.secondary)
                .frame(width: 24, height: Self.height)
                .contentShape(Rectangle())
                .onTapGesture { focusRequest += 1 }
                .accessibilityHidden(true)

            CharacterSearchTextField(
                text: state.query,
                placeholder: String(localized: "あ, ka, 日"),
                isActive: isActive,
                focusRequest: focusRequest,
                textColor: UIColor(theme.text.primary),
                placeholderColor: UIColor(theme.text.secondary),
                onEdit: { interactions.setQuery($0, on: surface) },
                onReturn: { interactions.nextMatch(on: surface) },
                onEditingChanged: { isEditing in
                    if isEditing {
                        interactions.beginEditing(on: surface)
                    } else {
                        interactions.endEditing(on: surface)
                    }
                }
            )
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)

            if hasQuery {
                if let counter = state.counter(for: script) {
                    counterLabel(current: counter.current, total: counter.total)
                }

                Button {
                    interactions.clear(on: surface)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(theme.text.secondary.opacity(0.8))
                        .frame(width: 34, height: Self.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear search"))
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, hasQuery ? 4 : 14)
        .frame(height: Self.height)
        .liquidChromeCapsule()
        .animation(.snappy(duration: 0.22), value: hasQuery)
    }

    private func counterLabel(current: Int, total: Int) -> some View {
        Text(verbatim: "\(current)/\(total)")
            .font(.system(size: 13, weight: .semibold).monospacedDigit())
            .foregroundStyle(theme.text.secondary)
            .contentTransition(.numericText())
            .lineLimit(1)
            .fixedSize()
            .animation(.snappy(duration: 0.2), value: current)
            .accessibilityLabel(total == 0 ? Text("No matches") : Text("Match \(current) of \(total)"))
    }
}

private struct CharacterSearchTextField: UIViewRepresentable {
    let text: String
    let placeholder: String
    let isActive: Bool
    let focusRequest: Int
    let textColor: UIColor
    let placeholderColor: UIColor
    let onEdit: (String) -> Void
    let onReturn: () -> Void
    let onEditingChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> CharacterSearchInput {
        let field = CharacterSearchInput()
        field.delegate = context.coordinator
        field.onInput = { [weak coordinator = context.coordinator] field in
            coordinator?.report(field)
        }
        field.font = Self.font()
        field.text = text
        field.returnKeyType = .search
        field.enablesReturnKeyAutomatically = true
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.smartInsertDeleteType = .no
        field.inlinePredictionType = .no
        field.writingToolsBehavior = .none
        field.accessibilityLabel = String(localized: "Search characters")
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: CharacterSearchInput, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        if field.text != text, !field.isComposing || text.isEmpty {
            field.text = text
        }
        if field.textColor != textColor {
            field.textColor = textColor
            field.tintColor = textColor
        }
        if coordinator.placeholder != placeholder || coordinator.placeholderColor != placeholderColor {
            coordinator.placeholder = placeholder
            coordinator.placeholderColor = placeholderColor
            field.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: placeholderColor]
            )
        }
        if coordinator.focusRequest != focusRequest {
            coordinator.focusRequest = focusRequest
            if isActive {
                Task { @MainActor in
                    _ = field.becomeFirstResponder()
                }
            }
        }
        if !isActive, field.isFirstResponder {
            Task { @MainActor in
                _ = field.resignFirstResponder()
            }
        }
    }

    private static func font() -> UIFont {
        let system = UIFont.systemFont(ofSize: 16, weight: .regular)
        let japanese = UIFontDescriptor(name: "HiraginoSans-W3", size: 16)
        return UIFont(descriptor: system.fontDescriptor.addingAttributes([.cascadeList: [japanese]]), size: 16)
    }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CharacterSearchTextField
        var placeholder: String?
        var placeholderColor: UIColor?
        var focusRequest: Int

        init(parent: CharacterSearchTextField) {
            self.parent = parent
            self.focusRequest = parent.focusRequest
        }

        func report(_ field: CharacterSearchInput) {
            parent.onEdit(field.text ?? "")
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            (textField as? CharacterSearchInput)?.inputDidChange()
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onEditingChanged(true)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.onEditingChanged(false)
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            guard let field = textField as? CharacterSearchInput else { return false }
            report(field)
            guard !field.isComposing, !field.justCommitted else { return false }
            parent.onReturn()
            return false
        }
    }
}

private final class CharacterSearchInput: UITextField {
    var onInput: ((CharacterSearchInput) -> Void)?
    private(set) var justCommitted = false
    private var wasComposing = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(inputDidChange), for: .editingChanged)
    }

    required init?(coder: NSCoder) {
        nil
    }

    var isComposing: Bool {
        markedTextRange != nil
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
}
