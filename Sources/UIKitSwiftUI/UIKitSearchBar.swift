import SwiftUI
import UIKit

/// A UIKit search bar with two-way query and focus bindings.
@MainActor
public struct UIKitSearchBar: UIViewRepresentable {
    public typealias UIViewType = UISearchBar

    private let text: Binding<String>
    private let isFocused: Binding<Bool>?
    private let prompt: String?
    private let configure: @MainActor (UISearchBar) -> Void
    private let onSubmit: @MainActor () -> Void
    private let onCancel: @MainActor () -> Void

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
        self.configure = configure
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    @MainActor
    public final class Coordinator: NSObject, UISearchBarDelegate {
        fileprivate var text: Binding<String>
        fileprivate var isFocused: Binding<Bool>?
        fileprivate var onSubmit: @MainActor () -> Void
        fileprivate var onCancel: @MainActor () -> Void

        fileprivate init(
            text: Binding<String>,
            isFocused: Binding<Bool>?,
            onSubmit: @escaping @MainActor () -> Void,
            onCancel: @escaping @MainActor () -> Void
        ) {
            self.text = text
            self.isFocused = isFocused
            self.onSubmit = onSubmit
            self.onCancel = onCancel
        }

        public func searchBar(
            _ searchBar: UISearchBar,
            textDidChange searchText: String
        ) {
            if text.wrappedValue != searchText {
                text.wrappedValue = searchText
            }
        }

        public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            onSubmit()
        }

        public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            onCancel()
        }

        public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            if isFocused?.wrappedValue != true {
                isFocused?.wrappedValue = true
            }
        }

        public func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            if isFocused?.wrappedValue != false {
                isFocused?.wrappedValue = false
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
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
        coordinator.text = text
        coordinator.isFocused = isFocused
        coordinator.onSubmit = onSubmit
        coordinator.onCancel = onCancel

        if searchBar.text != text.wrappedValue {
            searchBar.text = text.wrappedValue
        }
        searchBar.placeholder = prompt
        configure(searchBar)
        searchBar.delegate = coordinator

        guard let shouldFocus = isFocused?.wrappedValue else { return }
        if shouldFocus, !searchBar.searchTextField.isFirstResponder {
            searchBar.searchTextField.becomeFirstResponder()
        } else if !shouldFocus, searchBar.searchTextField.isFirstResponder {
            searchBar.searchTextField.resignFirstResponder()
        }
    }
}

