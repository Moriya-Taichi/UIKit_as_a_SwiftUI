import SwiftUI
import UIKit

/// A UIKit text view with two-way text and focus bindings.
@MainActor
public struct UIKitTextView: UIViewRepresentable {
    public typealias UIViewType = UITextView

    private let text: Binding<String>
    private let isFocused: Binding<Bool>?
    private let configure: @MainActor (UITextView) -> Void
    private let onEditingChanged: @MainActor (Bool) -> Void

    public init(
        text: Binding<String>,
        isFocused: Binding<Bool>? = nil,
        configure: @escaping @MainActor (UITextView) -> Void = { _ in },
        onEditingChanged: @escaping @MainActor (Bool) -> Void = { _ in }
    ) {
        self.text = text
        self.isFocused = isFocused
        self.configure = configure
        self.onEditingChanged = onEditingChanged
    }

    @MainActor
    public final class Coordinator: NSObject, UITextViewDelegate {
        fileprivate var text: Binding<String>
        fileprivate var isFocused: Binding<Bool>?
        fileprivate var onEditingChanged: @MainActor (Bool) -> Void

        fileprivate init(
            text: Binding<String>,
            isFocused: Binding<Bool>?,
            onEditingChanged: @escaping @MainActor (Bool) -> Void
        ) {
            self.text = text
            self.isFocused = isFocused
            self.onEditingChanged = onEditingChanged
        }

        public func textViewDidChange(_ textView: UITextView) {
            if text.wrappedValue != textView.text {
                text.wrappedValue = textView.text
            }
        }

        public func textViewDidBeginEditing(_ textView: UITextView) {
            if isFocused?.wrappedValue != true {
                isFocused?.wrappedValue = true
            }
            onEditingChanged(true)
        }

        public func textViewDidEndEditing(_ textView: UITextView) {
            if isFocused?.wrappedValue != false {
                isFocused?.wrappedValue = false
            }
            onEditingChanged(false)
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
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
        coordinator.text = text
        coordinator.isFocused = isFocused
        coordinator.onEditingChanged = onEditingChanged

        if textView.text != text.wrappedValue {
            textView.text = text.wrappedValue
        }
        configure(textView)
        textView.delegate = coordinator

        guard let shouldFocus = isFocused?.wrappedValue else { return }
        if shouldFocus, !textView.isFirstResponder {
            textView.becomeFirstResponder()
        } else if !shouldFocus, textView.isFirstResponder {
            textView.resignFirstResponder()
        }
    }
}

