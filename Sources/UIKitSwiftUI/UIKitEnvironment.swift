import SwiftUI
import UIKit

/// Applies environment overrides without losing a view's UIKit configuration
/// when an ancestor removes `.disabled` or `.scrollDisabled`.
@MainActor
final class UIKitEnvironmentState {
    private var configuredIsEnabled: Bool?
    private var configuredInteraction: Bool?
    private var configuredScrolling: Bool?
    private var configuredSearchEnabled: Bool?
    private let refresh = UIKitRefreshCoordinator()

    func update<ViewType: UIView>(
        _ view: ViewType,
        environment: EnvironmentValues,
        configure: (ViewType) -> Void
    ) {
        if let configuredIsEnabled, let control = view as? UIControl {
            control.isEnabled = configuredIsEnabled
        }
        if let configuredInteraction {
            view.isUserInteractionEnabled = configuredInteraction
        }
        if let configuredScrolling, let scrollView = view as? UIScrollView {
            scrollView.isScrollEnabled = configuredScrolling
        }
        if let configuredSearchEnabled, let searchBar = view as? UISearchBar {
            searchBar.searchTextField.isEnabled = configuredSearchEnabled
        }
        if let label = view as? UILabel {
            // Match SwiftUI's unlimited default. An explicit numberOfLines
            // configuration below takes precedence over an inherited value.
            label.numberOfLines = max(0, environment.lineLimit ?? 0)
        }

        configure(view)

        configuredInteraction = view.isUserInteractionEnabled
        view.isUserInteractionEnabled = view.isUserInteractionEnabled
            && environment.isEnabled
        if let control = view as? UIControl {
            configuredIsEnabled = control.isEnabled
            control.isEnabled = control.isEnabled && environment.isEnabled
        }
        if let searchBar = view as? UISearchBar {
            configuredSearchEnabled = searchBar.searchTextField.isEnabled
            searchBar.searchTextField.isEnabled = searchBar.searchTextField.isEnabled
                && environment.isEnabled
        }
        if let scrollView = view as? UIScrollView {
            configuredScrolling = scrollView.isScrollEnabled
            scrollView.isScrollEnabled = scrollView.isScrollEnabled
                && environment.isScrollEnabled
            refresh.update(scrollView, action: environment.refresh)
        }
    }

    func dismantle() {
        refresh.dismantle()
    }
}

struct UIKitSubmitActions: Sendable {
    var actions: [@MainActor @Sendable () -> Void] = []

    @MainActor
    func callAsFunction() {
        for action in actions {
            action()
        }
    }
}

private struct UIKitSubmitActionsKey: EnvironmentKey {
    static let defaultValue = UIKitSubmitActions()
}

extension EnvironmentValues {
    var uiKitSubmitActions: UIKitSubmitActions {
        get { self[UIKitSubmitActionsKey.self] }
        set { self[UIKitSubmitActionsKey.self] = newValue }
    }
}

public extension View {
    /// Receives accepted submissions from descendant `UIKitTextField` and
    /// `UIKitSearchBar` bridges, in either binding or model mode.
    ///
    /// Handlers accumulate from ancestors to descendants. These synchronous
    /// notifications do not consume `model.events`. This is a separate action
    /// from SwiftUI's `onSubmit` and is not affected by `submitScope`.
    func onUIKitSubmit(
        _ action: @escaping @MainActor @Sendable () -> Void
    ) -> some View {
        transformEnvironment(\.uiKitSubmitActions) {
            $0.actions.append(action)
        }
    }
}
