import SwiftUI
import UIKit

/// A UIKit text field with two-way SwiftUI bindings and delegate callbacks.
///
/// The bridge works in two mutually exclusive modes. The binding mode uses
/// bindings and closures supplied by the caller. The model mode is driven by
/// an observable `UIKitTextFieldModel`, which owns the text, the focus, and
/// the policy decisions; in that mode the bindings and closures are ignored.
@MainActor
public struct UIKitTextField: UIViewRepresentable {
    public typealias UIViewType = UITextField

    private let text: Binding<String>
    private let isFocused: Binding<Bool>?
    private let placeholder: String?
    private let model: UIKitTextFieldModel?
    private let configure: @MainActor (UITextField) -> Void
    private let onSubmit: @MainActor () -> Void
    private let shouldChange: @MainActor (NSRange, String) -> Bool

    /// Creates a text field driven by bindings and closures.
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
        model = nil
        self.configure = configure
        self.onSubmit = onSubmit
        self.shouldChange = shouldChange
    }

    /// Creates a text field driven by an observable model.
    ///
    /// The model owns the text, the focus, and every policy decision, so the
    /// binding-based parameters of the other initializer do not apply here.
    public init(
        _ placeholder: String? = nil,
        model: UIKitTextFieldModel,
        configure: @escaping @MainActor (UITextField) -> Void = { _ in }
    ) {
        self.placeholder = placeholder
        text = .constant("")
        isFocused = nil
        self.model = model
        self.configure = configure
        onSubmit = {}
        shouldChange = { _, _ in true }
    }

    @MainActor
    public final class Coordinator: NSObject, UITextFieldDelegate {
        fileprivate var model: UIKitTextFieldModel?
        fileprivate var text: Binding<String>
        fileprivate var isFocused: Binding<Bool>?
        fileprivate var onSubmit: @MainActor () -> Void
        fileprivate var shouldChange: @MainActor (NSRange, String) -> Bool

        fileprivate init(
            model: UIKitTextFieldModel?,
            text: Binding<String>,
            isFocused: Binding<Bool>?,
            onSubmit: @escaping @MainActor () -> Void,
            shouldChange: @escaping @MainActor (NSRange, String) -> Bool
        ) {
            self.model = model
            self.text = text
            self.isFocused = isFocused
            self.onSubmit = onSubmit
            self.shouldChange = shouldChange
        }

        @objc fileprivate func textDidChange(_ textField: UITextField) {
            let newValue = textField.text ?? ""
            if let model {
                model.handleTextChanged(newValue)
                return
            }
            if text.wrappedValue != newValue {
                text.wrappedValue = newValue
            }
        }

        /// Asks the model whether editing may begin. Without a model the
        /// field always begins editing.
        public func textFieldShouldBeginEditing(
            _ textField: UITextField
        ) -> Bool {
            guard let model else { return true }
            return model.shouldBeginEditing(textField)
        }

        /// Asks the model whether editing may end. Without a model the field
        /// always ends editing.
        public func textFieldShouldEndEditing(
            _ textField: UITextField
        ) -> Bool {
            guard let model else { return true }
            return model.shouldEndEditing(textField)
        }

        /// Asks the model whether the clear button may empty the field, and
        /// reports the clear to the model when it is allowed. Without a model
        /// the field always clears.
        public func textFieldShouldClear(_ textField: UITextField) -> Bool {
            guard let model else { return true }
            let shouldClear = model.shouldClear(textField)
            if shouldClear {
                model.handleCleared()
            }
            return shouldClear
        }

        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if let model {
                let shouldReturn = model.shouldReturn(textField)
                if shouldReturn {
                    model.handleSubmitted()
                }
                return shouldReturn
            }
            onSubmit()
            return true
        }

        public func textFieldDidBeginEditing(_ textField: UITextField) {
            if let model {
                model.handleEditingBegan()
                return
            }
            if isFocused?.wrappedValue != true {
                isFocused?.wrappedValue = true
            }
        }

        public func textFieldDidEndEditing(_ textField: UITextField) {
            if let model {
                model.handleEditingEnded()
                return
            }
            if isFocused?.wrappedValue != false {
                isFocused?.wrappedValue = false
            }
        }

        public func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            if let model {
                return model.shouldChangeText(
                    in: range,
                    replacement: string,
                    textField: textField
                )
            }
            return shouldChange(range, string)
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            model: model,
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
        coordinator.model = model
        coordinator.text = text
        coordinator.isFocused = isFocused
        coordinator.onSubmit = onSubmit
        coordinator.shouldChange = shouldChange

        // Reading the model here makes the update depend on its observable
        // state, so SwiftUI re-invokes `updateUIView` when the model changes.
        let currentText = model?.text ?? text.wrappedValue
        if textField.text != currentText {
            textField.text = currentText
        }
        textField.placeholder = placeholder
        configure(textField)
        textField.delegate = coordinator

        let desiredFocus: Bool?
        if let model {
            desiredFocus = model.isFocused
        } else {
            desiredFocus = isFocused?.wrappedValue
        }
        guard let shouldFocus = desiredFocus else { return }
        if shouldFocus, !textField.isFirstResponder {
            textField.becomeFirstResponder()
        } else if !shouldFocus, textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }
}

