#if canImport(UIKit)
import SwiftUI
import UIKit

/// A UIKit text view with two-way text and focus bindings.
///
/// The bridge works in two mutually exclusive modes. The binding mode uses
/// bindings and closures supplied by the caller. The model mode is driven by
/// an observable `UIKitTextViewModel`, which owns the text, the focus, and
/// the policy decisions; in that mode the bindings and closures are ignored.
@MainActor
public struct UIKitTextView: UIViewRepresentable {
    public typealias UIViewType = UITextView

    private let text: Binding<String>
    private let isFocused: Binding<Bool>?
    // stored property becomes type-erased — a stored property cannot have a
    // less-available type than its enclosing struct
    private let modelStorage: AnyObject?
    // Capture the observable values while SwiftUI evaluates the caller's
    // body. Reads made only from `updateUIView` don't establish a documented
    // SwiftUI observation dependency.
    private let modelText: String?
    private let modelIsFocused: Bool?
    private var configure: @MainActor (UITextView) -> Void
    private let onEditingChanged: @MainActor (Bool) -> Void

    @available(iOS 17.0, macCatalyst 17.0, *)
    private var model: UIKitTextViewModel? {
        modelStorage as? UIKitTextViewModel
    }

    /// Creates a text view driven by bindings and closures.
    public init(
        text: Binding<String>,
        isFocused: Binding<Bool>? = nil,
        configure: @escaping @MainActor (UITextView) -> Void = { _ in },
        onEditingChanged: @escaping @MainActor (Bool) -> Void = { _ in }
    ) {
        self.text = text
        self.isFocused = isFocused
        modelStorage = nil
        modelText = nil
        modelIsFocused = nil
        self.configure = configure
        self.onEditingChanged = onEditingChanged
    }

    /// Creates a text view driven by an observable model.
    ///
    /// The model owns the text, the focus, and every policy decision, so the
    /// binding-based parameters of the other initializer do not apply here.
    ///
    /// The observable model mode requires iOS 17 or newer.
    @available(iOS 17.0, macCatalyst 17.0, *)
    public init(
        model: UIKitTextViewModel,
        configure: @escaping @MainActor (UITextView) -> Void = { _ in }
    ) {
        text = .constant("")
        isFocused = nil
        modelStorage = model
        modelText = model.text
        modelIsFocused = model.isFocused
        self.configure = configure
        onEditingChanged = { _ in }
    }

    @MainActor
    public final class Coordinator: NSObject, UITextViewDelegate {
        fileprivate let environment = UIKitEnvironmentState()
        // stored property becomes type-erased — a stored property cannot have
        // a less-available type than its enclosing class
        fileprivate var modelStorage: AnyObject?
        fileprivate var text: Binding<String>
        fileprivate var isFocused: Binding<Bool>?
        fileprivate var onEditingChanged: @MainActor (Bool) -> Void

        @available(iOS 17.0, macCatalyst 17.0, *)
        fileprivate var model: UIKitTextViewModel? {
            modelStorage as? UIKitTextViewModel
        }

        fileprivate init(
            modelStorage: AnyObject?,
            text: Binding<String>,
            isFocused: Binding<Bool>?,
            onEditingChanged: @escaping @MainActor (Bool) -> Void
        ) {
            self.modelStorage = modelStorage
            self.text = text
            self.isFocused = isFocused
            self.onEditingChanged = onEditingChanged
        }

        /// Asks the model whether editing may begin. Without a model the
        /// view always begins editing.
        public func textViewShouldBeginEditing(
            _ textView: UITextView
        ) -> Bool {
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                return model.shouldBeginEditing(textView)
            }
            return true
        }

        /// Asks the model whether editing may end. Without a model the view
        /// always ends editing.
        public func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                return model.shouldEndEditing(textView)
            }
            return true
        }

        public func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                return model.shouldChangeText(
                    in: range,
                    replacement: text,
                    textView: textView
                )
            }
            return true
        }

        public func textViewDidChange(_ textView: UITextView) {
            let newValue = textView.text ?? ""
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                model.handleTextChanged(newValue)
                return
            }
            if text.wrappedValue != newValue {
                text.wrappedValue = newValue
            }
        }

        /// Reports selection changes to the model. The binding mode has no
        /// selection callback, so it ignores them.
        public func textViewDidChangeSelection(_ textView: UITextView) {
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                model.handleSelectionChanged(textView.selectedRange)
            }
        }

        public func textViewDidBeginEditing(_ textView: UITextView) {
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                model.handleEditingBegan()
                return
            }
            if isFocused?.wrappedValue != true {
                isFocused?.wrappedValue = true
            }
            onEditingChanged(true)
        }

        public func textViewDidEndEditing(_ textView: UITextView) {
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                model.handleEditingEnded()
                return
            }
            if isFocused?.wrappedValue != false {
                isFocused?.wrappedValue = false
            }
            onEditingChanged(false)
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            modelStorage: modelStorage,
            text: text,
            isFocused: isFocused,
            onEditingChanged: onEditingChanged
        )
    }

    public func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        synchronize(textView, coordinator: context.coordinator, environment: context.environment)
        return textView
    }

    public func updateUIView(_ uiView: UITextView, context: Context) {
        synchronize(uiView, coordinator: context.coordinator, environment: context.environment)
    }

    public static func dismantleUIView(
        _ uiView: UITextView,
        coordinator: Coordinator
    ) {
        coordinator.environment.dismantle()
        if uiView.delegate === coordinator {
            uiView.delegate = nil
        }
    }

    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width else { return nil }
        return uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
    }

    private func synchronize(
        _ textView: UITextView,
        coordinator: Coordinator,
        environment: EnvironmentValues
    ) {
        coordinator.modelStorage = modelStorage
        coordinator.text = text
        coordinator.isFocused = isFocused
        coordinator.onEditingChanged = onEditingChanged

        var currentText = text.wrappedValue
        var desiredFocus = isFocused?.wrappedValue
        if let modelText, let modelIsFocused {
            currentText = modelText
            desiredFocus = modelIsFocused
        }

        if textView.text != currentText {
            textView.text = currentText
        }
        coordinator.environment.update(textView, environment: environment, configure: configure)
        textView.delegate = coordinator

        guard let desiredFocus else { return }
        let shouldFocus = desiredFocus && environment.isEnabled
        if shouldFocus, !textView.isFirstResponder {
            textView.becomeFirstResponder()
        } else if !shouldFocus, textView.isFirstResponder {
            textView.resignFirstResponder()
        }
    }
}

extension UIKitTextView: UIKitViewConfiguring {
    public typealias UIKitViewType = UITextView

    /// Appends UIKit configuration to each update.
    public func configureUIKit(
        _ body: @escaping @MainActor (UITextView) -> Void
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
#endif
