import SwiftUI
import UIKit

/// Applies SwiftUI's interaction, scrolling, line-limit, and refresh settings.
@MainActor
final class UIKitEnvironmentState {
    private var configuredInteraction: Bool?
    private let refresh = UIKitRefreshCoordinator()

    func update<ViewType: UIView>(
        _ view: ViewType,
        environment: EnvironmentValues,
        configure: (ViewType) -> Void
    ) {
        if let configuredInteraction {
            view.isUserInteractionEnabled = configuredInteraction
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
            // SwiftUI can also assign this after updateUIView on newer OSes.
            // Make the environment authoritative on every supported OS.
            control.isEnabled = environment.isEnabled
        }
        if let searchBar = view as? UISearchBar {
            searchBar.searchTextField.isEnabled = environment.isEnabled
        }
        if let scrollView = view as? UIScrollView {
            scrollView.isScrollEnabled = environment.isScrollEnabled
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
