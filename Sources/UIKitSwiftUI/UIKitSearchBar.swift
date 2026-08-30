import SwiftUI
import UIKit

/// A UIKit search bar with two-way query and focus bindings.
///
/// The bridge works in two mutually exclusive modes. The binding mode uses
/// bindings and closures supplied by the caller. The model mode is driven by
/// an observable `UIKitSearchBarModel`, which owns the query text, the focus,
/// and the policy decisions; in that mode the bindings and closures are
/// ignored.
@MainActor
public struct UIKitSearchBar: UIViewRepresentable {
    public typealias UIViewType = UISearchBar

    private let text: Binding<String>
    private let isFocused: Binding<Bool>?
    private let prompt: String?
    private let model: UIKitSearchBarModel?
    private let configure: @MainActor (UISearchBar) -> Void
    private let onSubmit: @MainActor () -> Void
    private let onCancel: @MainActor () -> Void

    /// Creates a search bar driven by bindings and closures.
    public init(
        text: Binding<String>,
        prompt: String? = nil,
        isFocused: Binding<Bool>? = nil,
        configure: @escaping @MainActor (UISearchBar) -> Void = { _ in },
        onSubmit: @escaping @MainActor () -> Void = {},
        onCancel: @escaping @MainActor () -> Void = {}
    ) {
        self.text = text
        self.prompt = prompt
        self.isFocused = isFocused
        model = nil
        self.configure = configure
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    /// Creates a search bar driven by an observable model.
    ///
    /// The model owns the query text, the focus, and every policy decision,
    /// so the binding-based parameters of the other initializer do not apply
    /// here.
    public init(
        model: UIKitSearchBarModel,
        prompt: String? = nil,
        configure: @escaping @MainActor (UISearchBar) -> Void = { _ in }
    ) {
        text = .constant("")
        self.prompt = prompt
        isFocused = nil
        self.model = model
        self.configure = configure
        onSubmit = {}
        onCancel = {}
    }

    @MainActor
    public final class Coordinator: NSObject, UISearchBarDelegate {
        fileprivate var model: UIKitSearchBarModel?
        fileprivate var text: Binding<String>
        fileprivate var isFocused: Binding<Bool>?
        fileprivate var onSubmit: @MainActor () -> Void
        fileprivate var onCancel: @MainActor () -> Void

        fileprivate init(
            model: UIKitSearchBarModel?,
            text: Binding<String>,
            isFocused: Binding<Bool>?,
            onSubmit: @escaping @MainActor () -> Void,
            onCancel: @escaping @MainActor () -> Void
        ) {
            self.model = model
            self.text = text
            self.isFocused = isFocused
            self.onSubmit = onSubmit
            self.onCancel = onCancel
        }

        /// Asks the model whether editing may begin. Without a model the
        /// search bar always begins editing.
        public func searchBarShouldBeginEditing(
            _ searchBar: UISearchBar
        ) -> Bool {
            guard let model else { return true }
            return model.shouldBeginEditing(searchBar)
        }

        /// Asks the model whether editing may end. Without a model the
        /// search bar always ends editing.
        public func searchBarShouldEndEditing(
            _ searchBar: UISearchBar
        ) -> Bool {
            guard let model else { return true }
            return model.shouldEndEditing(searchBar)
        }

        public func searchBar(
            _ searchBar: UISearchBar,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            guard let model else { return true }
            return model.shouldChangeText(
                in: range,
                replacement: text,
                searchBar: searchBar
            )
        }

        public func searchBar(
            _ searchBar: UISearchBar,
            textDidChange searchText: String
        ) {
            if let model {
                model.handleTextChanged(searchText)
                return
            }
            if text.wrappedValue != searchText {
                text.wrappedValue = searchText
            }
        }

        public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            if let model {
                model.handleSubmitted()
                return
            }
            onSubmit()
        }

        /// Reports the cancel button to the model, which leaves the query
        /// text untouched, or to the closure in binding mode.
        public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            if let model {
                model.handleCancelled()
                return
            }
            onCancel()
        }

        public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            if let model {
                model.handleEditingBegan()
                return
            }
            if isFocused?.wrappedValue != true {
                isFocused?.wrappedValue = true
            }
        }

        public func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            if let model {
                model.handleEditingEnded()
                return
            }
            if isFocused?.wrappedValue != false {
                isFocused?.wrappedValue = false
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            model: model,
            text: text,
            isFocused: isFocused,
            onSubmit: onSubmit,
            onCancel: onCancel
        )
    }

    public func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        synchronize(searchBar, coordinator: context.coordinator)
        return searchBar
    }

    public func updateUIView(_ uiView: UISearchBar, context: Context) {
        synchronize(uiView, coordinator: context.coordinator)
    }

    public static func dismantleUIView(
        _ uiView: UISearchBar,
        coordinator: Coordinator
    ) {
        if uiView.delegate === coordinator {
            uiView.delegate = nil
        }
    }

    private func synchronize(
        _ searchBar: UISearchBar,
        coordinator: Coordinator
    ) {
        coordinator.model = model
        coordinator.text = text
        coordinator.isFocused = isFocused
        coordinator.onSubmit = onSubmit
        coordinator.onCancel = onCancel

        // Reading the model here makes the update depend on its observable
        // state, so SwiftUI re-invokes `updateUIView` when the model changes.
        let currentText = model?.text ?? text.wrappedValue
        if searchBar.text != currentText {
            searchBar.text = currentText
        }
        searchBar.placeholder = prompt
        configure(searchBar)
        searchBar.delegate = coordinator

        let desiredFocus: Bool?
        if let model {
            desiredFocus = model.isFocused
        } else {
            desiredFocus = isFocused?.wrappedValue
        }
        guard let shouldFocus = desiredFocus else { return }
        if shouldFocus, !searchBar.searchTextField.isFirstResponder {
            searchBar.searchTextField.becomeFirstResponder()
        } else if !shouldFocus, searchBar.searchTextField.isFirstResponder {
            searchBar.searchTextField.resignFirstResponder()
        }
    }
}

