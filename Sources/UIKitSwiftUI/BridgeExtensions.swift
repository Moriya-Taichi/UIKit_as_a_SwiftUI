#if canImport(UIKit)
import SwiftUI
import UIKit

/// Namespace for bridging existing UIKit instances without erasing their type.
public enum UIKitBridge {
    /// Presents an existing view instance in a SwiftUI hierarchy.
    @MainActor
    public static func view<ViewType: UIView>(
        _ view: ViewType
    ) -> UIKitView<ViewType> {
        UIKitView(view)
    }

    /// Presents an existing controller instance in a SwiftUI hierarchy.
    @MainActor
    public static func controller<ControllerType: UIViewController>(
        _ controller: ControllerType
    ) -> UIKitViewController<ControllerType> {
        UIKitViewController(controller)
    }
}

public extension View {
    /// Creates a UIKit hosting controller for this SwiftUI value.
    @MainActor
    func hostedInUIKit() -> UIHostingController<Self> {
        UIHostingController(rootView: self)
    }
}
#endif
