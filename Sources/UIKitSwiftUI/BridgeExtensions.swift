import SwiftUI
import UIKit

public extension UIView {
    /// Presents this view instance in a SwiftUI hierarchy.
    func asSwiftUI() -> UIKitView<Self> {
        UIKitView(self)
    }
}

public extension UIViewController {
    /// Presents this controller instance in a SwiftUI hierarchy.
    func asSwiftUI() -> UIKitViewController<Self> {
        UIKitViewController(self)
    }
}

public extension View {
    /// Creates a UIKit hosting controller for this SwiftUI value.
    @MainActor
    func hostedInUIKit() -> UIHostingController<Self> {
        UIHostingController(rootView: self)
    }
}
