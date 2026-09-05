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
    private var prompt: UIKitDisplayText?
    // stored property becomes type-erased — a stored property cannot have a
    // less-available type than its enclosing struct
    private let modelStorage: AnyObject?
    // Capture the observable values while SwiftUI evaluates the caller's
    // body. Reads made only from `updateUIView` don't establish a documented
    // SwiftUI observation dependency.
    private let modelText: String?
    private let modelIsFocused: Bool?
    private var configure: @MainActor (UISearchBar) -> Void
    private let onSubmit: @MainActor () -> Void
    private let onCancel: @MainActor () -> Void

    @available(iOS 17.0, macCatalyst 17.0, *)
    private var model: UIKitSearchBarModel? {
        modelStorage as? UIKitSearchBarModel
    }

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
        self.prompt = prompt.map(UIKitDisplayText.verbatim)
        self.isFocused = isFocused
        modelStorage = nil
        modelText = nil
        modelIsFocused = nil
        self.configure = configure
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    /// Creates a search bar driven by an observable model.
    ///
    /// The model owns the query text, the focus, and every policy decision,
    /// so the binding-based parameters of the other initializer do not apply
    /// here.
    ///
    /// The observable model mode requires iOS 17 or newer.
    @available(iOS 17.0, macCatalyst 17.0, *)
    public init(
        model: UIKitSearchBarModel,
        prompt: String? = nil,
        configure: @escaping @MainActor (UISearchBar) -> Void = { _ in }
    ) {
        text = .constant("")
        self.prompt = prompt.map(UIKitDisplayText.verbatim)
        isFocused = nil
        modelStorage = model
        modelText = model.text
        modelIsFocused = model.isFocused
        self.configure = configure
        onSubmit = {}
        onCancel = {}
    }

    @MainActor
    public final class Coordinator: NSObject, UISearchBarDelegate {
        fileprivate let environment = UIKitEnvironmentState()
        // stored property becomes type-erased — a stored property cannot have
        // a less-available type than its enclosing class
        fileprivate var modelStorage: AnyObject?
        fileprivate var text: Binding<String>
        fileprivate var isFocused: Binding<Bool>?
        fileprivate var submitActions = UIKitSubmitActions()
        fileprivate var onSubmit: @MainActor () -> Void
        fileprivate var onCancel: @MainActor () -> Void

        @available(iOS 17.0, macCatalyst 17.0, *)
        fileprivate var model: UIKitSearchBarModel? {
            modelStorage as? UIKitSearchBarModel
        }

        fileprivate init(
            modelStorage: AnyObject?,
            text: Binding<String>,
            isFocused: Binding<Bool>?,
            onSubmit: @escaping @MainActor () -> Void,
            onCancel: @escaping @MainActor () -> Void
        ) {
            self.modelStorage = modelStorage
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
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                return model.shouldBeginEditing(searchBar)
            }
            return true
        }

        /// Asks the model whether editing may end. Without a model the
        /// search bar always ends editing.
        public func searchBarShouldEndEditing(
            _ searchBar: UISearchBar
        ) -> Bool {
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                return model.shouldEndEditing(searchBar)
            }
            return true
        }

        public func searchBar(
            _ searchBar: UISearchBar,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                return model.shouldChangeText(
                    in: range,
                    replacement: text,
                    searchBar: searchBar
                )
            }
            return true
        }

        public func searchBar(
            _ searchBar: UISearchBar,
            textDidChange searchText: String
        ) {
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                model.handleTextChanged(searchText)
                return
            }
            if text.wrappedValue != searchText {
                text.wrappedValue = searchText
            }
        }

        public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                model.handleSubmitted()
                submitActions()
                return
            }
            onSubmit()
            submitActions()
        }

        /// Reports the cancel button to the model, which leaves the query
        /// text untouched, or to the closure in binding mode.
        public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                model.handleCancelled()
                return
            }
            onCancel()
        }

        public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
                model.handleEditingBegan()
                return
            }
            if isFocused?.wrappedValue != true {
                isFocused?.wrappedValue = true
            }
        }

        public func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            if #available(iOS 17.0, macCatalyst 17.0, *), let model {
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
            modelStorage: modelStorage,
            text: text,
            isFocused: isFocused,
            onSubmit: onSubmit,
            onCancel: onCancel
        )
    }

    public func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        synchronize(searchBar, coordinator: context.coordinator, environment: context.environment)
        return searchBar
    }

    public func updateUIView(_ uiView: UISearchBar, context: Context) {
        synchronize(uiView, coordinator: context.coordinator, environment: context.environment)
    }

    public static func dismantleUIView(
        _ uiView: UISearchBar,
        coordinator: Coordinator
    ) {
        coordinator.environment.dismantle()
        if uiView.delegate === coordinator {
            uiView.delegate = nil
        }
    }

    private func synchronize(
        _ searchBar: UISearchBar,
        coordinator: Coordinator,
        environment: EnvironmentValues
    ) {
        coordinator.modelStorage = modelStorage
        coordinator.text = text
        coordinator.isFocused = isFocused
        coordinator.submitActions = environment.uiKitSubmitActions
        coordinator.onSubmit = onSubmit
        coordinator.onCancel = onCancel

        var currentText = text.wrappedValue
        var desiredFocus = isFocused?.wrappedValue
        if let modelText, let modelIsFocused {
            currentText = modelText
            desiredFocus = modelIsFocused
        }

        if searchBar.text != currentText {
            searchBar.text = currentText
        }
        searchBar.placeholder = prompt?.resolve(in: environment.locale)
        coordinator.environment.update(searchBar, environment: environment, configure: configure)
        searchBar.delegate = coordinator

        guard let desiredFocus else { return }
        let shouldFocus = desiredFocus && environment.isEnabled
        if shouldFocus, !searchBar.searchTextField.isFirstResponder {
            searchBar.searchTextField.becomeFirstResponder()
        } else if !shouldFocus, searchBar.searchTextField.isFirstResponder {
            searchBar.searchTextField.resignFirstResponder()
        }
    }
}

extension UIKitSearchBar: UIKitViewConfiguring {
    public typealias UIKitViewType = UISearchBar

    /// Appends UIKit configuration to each update.
    public func configureUIKit(
        _ body: @escaping @MainActor (UISearchBar) -> Void
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

public extension UIKitSearchBar {
    /// Creates a bound input with a placeholder localized using the environment locale.
    init(
        localizedPrompt prompt: LocalizedStringResource,
        text: Binding<String>,
        isFocused: Binding<Bool>? = nil,
        configure: @escaping @MainActor (UISearchBar) -> Void = { _ in },
        onSubmit: @escaping @MainActor () -> Void = {},
        onCancel: @escaping @MainActor () -> Void = {}
    ) {
        self.init(
            text: text, isFocused: isFocused, configure: configure,
            onSubmit: onSubmit, onCancel: onCancel
        )
        self.prompt = .localized(prompt)
    }

    /// Creates a bound input with a placeholder displayed without localization.
    init(
        verbatimPrompt prompt: String,
        text: Binding<String>,
        isFocused: Binding<Bool>? = nil,
        configure: @escaping @MainActor (UISearchBar) -> Void = { _ in },
        onSubmit: @escaping @MainActor () -> Void = {},
        onCancel: @escaping @MainActor () -> Void = {}
    ) {
        self.init(
            text: text, isFocused: isFocused, configure: configure,
            onSubmit: onSubmit, onCancel: onCancel
        )
        self.prompt = .verbatim(prompt)
    }

    /// Creates a model-driven input with a localized placeholder.
    @available(iOS 17.0, macCatalyst 17.0, *)
    init(
        localizedPrompt prompt: LocalizedStringResource,
        model: UIKitSearchBarModel,
        configure: @escaping @MainActor (UISearchBar) -> Void = { _ in }
    ) {
        self.init(model: model, configure: configure)
        self.prompt = .localized(prompt)
    }

    /// Creates a model-driven input with an unlocalized placeholder.
    @available(iOS 17.0, macCatalyst 17.0, *)
    init(
        verbatimPrompt prompt: String,
        model: UIKitSearchBarModel,
        configure: @escaping @MainActor (UISearchBar) -> Void = { _ in }
    ) {
        self.init(model: model, configure: configure)
        self.prompt = .verbatim(prompt)
    }
}
