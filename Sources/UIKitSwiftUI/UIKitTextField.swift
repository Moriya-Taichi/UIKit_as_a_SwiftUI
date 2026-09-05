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
    private var placeholder: UIKitDisplayText?
    // stored property becomes type-erased — a stored property cannot have a
    // less-available type than its enclosing struct
    private let modelStorage: AnyObject?
    // Capture the observable values while SwiftUI evaluates the caller's
    // body. Reads made only from `updateUIView` don't establish a documented
    // SwiftUI observation dependency.
    private let modelText: String?
    private let modelIsFocused: Bool?
    private var configure: @MainActor (UITextField) -> Void
    private let onSubmit: @MainActor () -> Void
    private let shouldChange: @MainActor (NSRange, String) -> Bool

    @available(iOS 17.0, macCatalyst 17.0, *)
    private var model: UIKitTextFieldModel? {
        modelStorage as? UIKitTextFieldModel
    }

    /// Creates a text field driven by bindings and closures.
    public init(
        _ placeholder: String? = nil,
        text: Binding<String>,
        isFocused: Binding<Bool>? = nil,
        configure: @escaping @MainActor (UITextField) -> Void = { _ in },
        onSubmit: @escaping @MainActor () -> Void = {},
        shouldChange: @escaping @MainActor (NSRange, String) -> Bool = { _, _ in true }
    ) {
        self.placeholder = placeholder.map(UIKitDisplayText.verbatim)
        self.text = text
        self.isFocused = isFocused
        modelStorage = nil
        modelText = nil
        modelIsFocused = nil
        self.configure = configure
        self.onSubmit = onSubmit
        self.shouldChange = shouldChange
    }

    /// Creates a text field driven by an observable model.
    ///
    /// The model owns the text, the focus, and every policy decision, so the
    /// binding-based parameters of the other initializer do not apply here.
    ///
    /// The observable model mode requires iOS 17 or newer.
    @available(iOS 17.0, macCatalyst 17.0, *)
    public init(
        _ placeholder: String? = nil,
        model: UIKitTextFieldModel,
        configure: @escaping @MainActor (UITextField) -> Void = { _ in }
    ) {
        self.placeholder = placeholder.map(UIKitDisplayText.verbatim)
        text = .constant("")
        isFocused = nil
        modelStorage = model
        modelText = model.text
        modelIsFocused = model.isFocused
        self.configure = configure
        onSubmit = {}
        shouldChange = { _, _ in true }
    }

    @MainActor
    public final class Coordinator: NSObject, UITextFieldDelegate {
        fileprivate let environment = UIKitEnvironmentState()
        // stored property becomes type-erased — a stored property cannot have
        // a less-available type than its enclosing class
        fileprivate var modelStorage: AnyObject?
        fileprivate var text: Binding<String>
        fileprivate var isFocused: Binding<Bool>?
        fileprivate var submitActions = UIKitSubmitActions()
        fileprivate var onSubmit: @MainActor () -> Void
        fileprivate var shouldChange: @MainActor (NSRange, String) -> Bool

        @available(iOS 17.0, macCatalyst 17.0, *)
        fileprivate var model: UIKitTextFieldModel? {
            modelStorage as? UIKitTextFieldModel
        }

        fileprivate init(
            modelStorage: AnyObject?,
            text: Binding<String>,
            isFocused: Binding<Bool>?,
            onSubmit: @escaping @MainActor () -> Void,
            shouldChange: @escaping @MainActor (NSRange, String) -> Bool
        ) {
            self.modelStorage = modelStorage
            self.text = text
            self.isFocused = isFocused
            self.onSubmit = onSubmit
            self.shouldChange = shouldChange
        }

        @objc fileprivate func textDidChange(_ textField: UITextField) {
            let newValue = textField.text ?? ""
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
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
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                return model.shouldBeginEditing(textField)
            }
            return true
        }

        /// Asks the model whether editing may end. Without a model the field
        /// always ends editing.
        public func textFieldShouldEndEditing(
            _ textField: UITextField
        ) -> Bool {
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                return model.shouldEndEditing(textField)
            }
            return true
        }

        /// Asks the model whether the clear button may empty the field, and
        /// reports the clear to the model when it is allowed. Without a model
        /// the field always clears.
        public func textFieldShouldClear(_ textField: UITextField) -> Bool {
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                let shouldClear = model.shouldClear(textField)
                if shouldClear {
                    model.handleCleared()
                }
                return shouldClear
            }
            return true
        }

        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                let shouldReturn = model.shouldReturn(textField)
                if shouldReturn {
                    model.handleSubmitted()
                    submitActions()
                }
                return shouldReturn
            }
            onSubmit()
            submitActions()
            return true
        }

        public func textFieldDidBeginEditing(_ textField: UITextField) {
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                model.handleEditingBegan()
                return
            }
            if isFocused?.wrappedValue != true {
                isFocused?.wrappedValue = true
            }
        }

        public func textFieldDidEndEditing(_ textField: UITextField) {
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
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
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
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
            modelStorage: modelStorage,
            text: text,
            isFocused: isFocused,
            onSubmit: onSubmit,
            shouldChange: shouldChange
        )
    }

    public func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        synchronize(textField, coordinator: context.coordinator, environment: context.environment)
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        return textField
    }

    public func updateUIView(_ uiView: UITextField, context: Context) {
        synchronize(uiView, coordinator: context.coordinator, environment: context.environment)
    }

    public static func dismantleUIView(
        _ uiView: UITextField,
        coordinator: Coordinator
    ) {
        coordinator.environment.dismantle()
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
        coordinator: Coordinator,
        environment: EnvironmentValues
    ) {
        coordinator.modelStorage = modelStorage
        coordinator.text = text
        coordinator.isFocused = isFocused
        coordinator.submitActions = environment.uiKitSubmitActions
        coordinator.onSubmit = onSubmit
        coordinator.shouldChange = shouldChange

        var currentText = text.wrappedValue
        var desiredFocus = isFocused?.wrappedValue
        if let modelText, let modelIsFocused {
            currentText = modelText
            desiredFocus = modelIsFocused
        }

        if textField.text != currentText {
            textField.text = currentText
        }
        textField.placeholder = placeholder?.resolve(in: environment.locale)
        coordinator.environment.update(textField, environment: environment, configure: configure)
        textField.delegate = coordinator

        guard let desiredFocus else { return }
        let shouldFocus = desiredFocus && environment.isEnabled
        if shouldFocus, !textField.isFirstResponder {
            textField.becomeFirstResponder()
        } else if !shouldFocus, textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }
}

extension UIKitTextField: UIKitViewConfiguring {
    public typealias UIKitViewType = UITextField

    /// Appends UIKit configuration to each update.
    public func configureUIKit(
        _ body: @escaping @MainActor (UITextField) -> Void
    ) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { view in
            previous(view)
            body(view)
        }
        return copy
    }
}

public extension UIKitTextField {
    /// Creates a bound input with a placeholder localized using the environment locale.
    init(
        localized placeholder: LocalizedStringResource,
        text: Binding<String>,
        isFocused: Binding<Bool>? = nil,
        configure: @escaping @MainActor (UITextField) -> Void = { _ in },
        onSubmit: @escaping @MainActor () -> Void = {},
        shouldChange: @escaping @MainActor (NSRange, String) -> Bool = { _, _ in true }
    ) {
        self.init(
            text: text, isFocused: isFocused, configure: configure,
            onSubmit: onSubmit, shouldChange: shouldChange
        )
        self.placeholder = .localized(placeholder)
    }

    /// Creates a bound input with a placeholder displayed without localization.
    init(
        verbatim placeholder: String,
        text: Binding<String>,
        isFocused: Binding<Bool>? = nil,
        configure: @escaping @MainActor (UITextField) -> Void = { _ in },
        onSubmit: @escaping @MainActor () -> Void = {},
        shouldChange: @escaping @MainActor (NSRange, String) -> Bool = { _, _ in true }
    ) {
        self.init(
            text: text, isFocused: isFocused, configure: configure,
            onSubmit: onSubmit, shouldChange: shouldChange
        )
        self.placeholder = .verbatim(placeholder)
    }

    /// Creates a model-driven input with a localized placeholder.
    @available(iOS 17.0, macCatalyst 17.0, *)
    init(
        localized placeholder: LocalizedStringResource,
        model: UIKitTextFieldModel,
        configure: @escaping @MainActor (UITextField) -> Void = { _ in }
    ) {
        self.init(model: model, configure: configure)
        self.placeholder = .localized(placeholder)
    }

    /// Creates a model-driven input with an unlocalized placeholder.
    @available(iOS 17.0, macCatalyst 17.0, *)
    init(
        verbatim placeholder: String,
        model: UIKitTextFieldModel,
        configure: @escaping @MainActor (UITextField) -> Void = { _ in }
    ) {
        self.init(model: model, configure: configure)
        self.placeholder = .verbatim(placeholder)
    }
}
