import SwiftUI
import UIKit

/// A UIKit text field with two-way SwiftUI bindings and delegate callbacks.
@MainActor
public struct UIKitTextField: UIViewRepresentable {
    public typealias UIViewType = UITextField

    private let text: Binding<String>
    private let isFocused: Binding<Bool>?
    private let placeholder: String?
    private let configure: @MainActor (UITextField) -> Void
    private let onSubmit: @MainActor () -> Void
    private let shouldChange: @MainActor (NSRange, String) -> Bool

    public init(
        _ placeholder: String? = nil,
        text: Binding<String>,
        isFocused: Binding<Bool>? = nil,
        configure: @escaping @MainActor (UITextField) -> Void = { _ in },
        onSubmit: @escaping @MainActor () -> Void = {},
        shouldChange: @escaping @MainActor (NSRange, String) -> Bool = { _, _ in true }
    ) {
        self.placeholder = placeholder
        self.text = text
        self.isFocused = isFocused
        self.configure = configure
        self.onSubmit = onSubmit
        self.shouldChange = shouldChange
    }

    @MainActor
    public final class Coordinator: NSObject, UITextFieldDelegate {
        fileprivate var text: Binding<String>
        fileprivate var isFocused: Binding<Bool>?
        fileprivate var onSubmit: @MainActor () -> Void
        fileprivate var shouldChange: @MainActor (NSRange, String) -> Bool

        fileprivate init(
            text: Binding<String>,
            isFocused: Binding<Bool>?,
            onSubmit: @escaping @MainActor () -> Void,
            shouldChange: @escaping @MainActor (NSRange, String) -> Bool
        ) {
            self.text = text
            self.isFocused = isFocused
            self.onSubmit = onSubmit
            self.shouldChange = shouldChange
        }

        @objc fileprivate func textDidChange(_ textField: UITextField) {
            let newValue = textField.text ?? ""
            if text.wrappedValue != newValue {
                text.wrappedValue = newValue
            }
        }

        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onSubmit()
            return true
        }

        public func textFieldDidBeginEditing(_ textField: UITextField) {
            if isFocused?.wrappedValue != true {
                isFocused?.wrappedValue = true
            }
        }

        public func textFieldDidEndEditing(_ textField: UITextField) {
            if isFocused?.wrappedValue != false {
                isFocused?.wrappedValue = false
            }
        }

        public func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            shouldChange(range, string)
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            text: text,
            isFocused: isFocused,
            onSubmit: onSubmit,
            shouldChange: shouldChange
        )
    }

    public func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        synchronize(textField, coordinator: context.coordinator)
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        return textField
    }

    public func updateUIView(_ uiView: UITextField, context: Context) {
        synchronize(uiView, coordinator: context.coordinator)
    }

    public static func dismantleUIView(
        _ uiView: UITextField,
        coordinator: Coordinator
    ) {
        uiView.removeTarget(
            coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        if uiView.delegate === coordinator {
            uiView.delegate = nil
        }
    }

    private func synchronize(
        _ textField: UITextField,
        coordinator: Coordinator
    ) {
        coordinator.text = text
        coordinator.isFocused = isFocused
        coordinator.onSubmit = onSubmit
        coordinator.shouldChange = shouldChange

        if textField.text != text.wrappedValue {
            textField.text = text.wrappedValue
        }
        textField.placeholder = placeholder
        configure(textField)
        textField.delegate = coordinator

        guard let shouldFocus = isFocused?.wrappedValue else { return }
        if shouldFocus, !textField.isFirstResponder {
            textField.becomeFirstResponder()
        } else if !shouldFocus, textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }
}

