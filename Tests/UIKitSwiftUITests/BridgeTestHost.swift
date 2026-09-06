#if canImport(UIKit)
import SwiftUI
import UIKit
import XCTest

@MainActor
final class BridgeTestHost<Content: View> {
    let controller: UIHostingController<Content>
    let window: UIWindow

    init(_ content: Content) {
        controller = UIHostingController(rootView: content)
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    func close() {
        window.isHidden = true
        window.rootViewController = nil
    }

    func view<T: UIView>(_ type: T.Type, id: String) -> T? {
        func find(_ root: UIView) -> T? {
            if let match = root as? T, match.accessibilityIdentifier == id {
                return match
            }
            for child in root.subviews {
                if let match = find(child) { return match }
            }
            return nil
        }
        return find(controller.view)
    }
}

@MainActor
func waitForBridge(_ condition: @escaping @MainActor () -> Bool) async -> Bool {
    for _ in 0..<200 {
        if condition() { return true }
        try? await Task<Never, Never>.sleep(nanoseconds: 10_000_000)
    }
    return condition()
}
#endif
