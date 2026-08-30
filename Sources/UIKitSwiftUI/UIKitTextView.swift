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
    private let model: UIKitTextViewModel?
    private let configure: @MainActor (UITextView) -> Void
    private let onEditingChanged: @MainActor (Bool) -> Void

    /// Creates a text view driven by bindings and closures.
    public init(
        text: Binding<String>,
        isFocused: Binding<Bool>? = nil,
        configure: @escaping @MainActor (UITextView) -> Void = { _ in },
        onEditingChanged: @escaping @MainActor (Bool) -> Void = { _ in }
    ) {
        self.text = text
        self.isFocused = isFocused
        model = nil
        self.configure = configure
        self.onEditingChanged = onEditingChanged
    }

    /// Creates a text view driven by an observable model.
    ///
    /// The model owns the text, the focus, and every policy decision, so the
    /// binding-based parameters of the other initializer do not apply here.
    public init(
        model: UIKitTextViewModel,
        configure: @escaping @MainActor (UITextView) -> Void = { _ in }
    ) {
        text = .constant("")
        isFocused = nil
        self.model = model
        self.configure = configure
        onEditingChanged = { _ in }
    }

    @MainActor
    public final class Coordinator: NSObject, UITextViewDelegate {
        fileprivate var model: UIKitTextViewModel?
        fileprivate var text: Binding<String>
        fileprivate var isFocused: Binding<Bool>?
        fileprivate var onEditingChanged: @MainActor (Bool) -> Void

        fileprivate init(
            model: UIKitTextViewModel?,
            text: Binding<String>,
            isFocused: Binding<Bool>?,
            onEditingChanged: @escaping @MainActor (Bool) -> Void
        ) {
            self.model = model
            self.text = text
            self.isFocused = isFocused
            self.onEditingChanged = onEditingChanged
        }

        /// Asks the model whether editing may begin. Without a model the
        /// view always begins editing.
        public func textViewShouldBeginEditing(
            _ textView: UITextView
        ) -> Bool {
            guard let model else { return true }
            return model.shouldBeginEditing(textView)
        }

        /// Asks the model whether editing may end. Without a model the view
        /// always ends editing.
        public func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
            guard let model else { return true }
            return model.shouldEndEditing(textView)
        }

        public func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            guard let model else { return true }
            return model.shouldChangeText(
                in: range,
                replacement: text,
                textView: textView
            )
        }

        public func textViewDidChange(_ textView: UITextView) {
            let newValue = textView.text ?? ""
            if let model {
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
            guard let model else { return }
            model.handleSelectionChanged(textView.selectedRange)
        }

        public func textViewDidBeginEditing(_ textView: UITextView) {
            if let model {
                model.handleEditingBegan()
                return
            }
            if isFocused?.wrappedValue != true {
                isFocused?.wrappedValue = true
            }
            onEditingChanged(true)
        }

        public func textViewDidEndEditing(_ textView: UITextView) {
            if let model {
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
            model: model,
            text: text,
            isFocused: isFocused,
            onEditingChanged: onEditingChanged
        )
    }

    public func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        synchronize(textView, coordinator: context.coordinator)
        return textView
    }

    public func updateUIView(_ uiView: UITextView, context: Context) {
        synchronize(uiView, coordinator: context.coordinator)
    }

    public static func dismantleUIView(
        _ uiView: UITextView,
        coordinator: Coordinator
    ) {
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
        coordinator: Coordinator
    ) {
        coordinator.model = model
        coordinator.text = text
        coordinator.isFocused = isFocused
        coordinator.onEditingChanged = onEditingChanged

        // Reading the model here makes the update depend on its observable
        // state, so SwiftUI re-invokes `updateUIView` when the model changes.
        let currentText = model?.text ?? text.wrappedValue
        if textView.text != currentText {
            textView.text = currentText
        }
        configure(textView)
        textView.delegate = coordinator

        let desiredFocus: Bool?
        if let model {
            desiredFocus = model.isFocused
        } else {
            desiredFocus = isFocused?.wrappedValue
        }
        guard let shouldFocus = desiredFocus else { return }
        if shouldFocus, !textView.isFirstResponder {
            textView.becomeFirstResponder()
        } else if !shouldFocus, textView.isFirstResponder {
            textView.resignFirstResponder()
        }
    }
}

