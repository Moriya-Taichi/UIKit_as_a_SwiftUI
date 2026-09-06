#if os(macOS)
import SwiftUI
import AppKit

/// Namespace for bridging existing AppKit instances without erasing their type.
public enum AppKitBridge {
    /// Presents an existing view instance in a SwiftUI hierarchy.
    @MainActor
    public static func view<ViewType: NSView>(
        _ view: ViewType
    ) -> AppKitView<ViewType> {
        AppKitView(view)
    }

    /// Presents an existing controller instance in a SwiftUI hierarchy.
    @MainActor
    public static func controller<ControllerType: NSViewController>(
        _ controller: ControllerType
    ) -> AppKitViewController<ControllerType> {
        AppKitViewController(controller)
    }
}

public extension View {
    /// Creates an AppKit hosting controller for this SwiftUI value.
    @MainActor
    func hostedInAppKit() -> NSHostingController<Self> {
        NSHostingController(rootView: self)
    }
}
#endif
