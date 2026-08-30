import SwiftUI
import UIKit
import XCTest
@testable import UIKitSwiftUI

@MainActor
final class ModuleTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertEqual(UIView().frame, .zero)
    }

    func testUniversalBridgeAcceptsCustomUIViewSubclass() {
        final class CustomView: UIView {}

        let bridge = UIKitView(make: CustomView.init)

        XCTAssertTrue(type(of: bridge) == UIKitView<CustomView>.self)
    }

    func testBridgeCanWrapAnExistingView() {
        let label = UILabel()

        _ = UIKitView(label).configure { $0.text = "Updated" }

        XCTAssertNil(label.text)
    }

    func testCoordinatedBridgeAcceptsDelegateValue() {
        final class Delegate: NSObject, UITextFieldDelegate {}

        let bridge = UIKitCoordinatedView(
            makeCoordinator: Delegate.init,
            make: { delegate, _ in
                let textField = UITextField()
                textField.delegate = delegate
                return textField
            }
        )

        XCTAssertTrue(
            type(of: bridge) == UIKitCoordinatedView<UITextField, Delegate>.self
        )
    }

    func testControllerBridgeAcceptsCustomControllerSubclass() {
        final class CustomController: UIViewController {}

        let bridge = UIKitViewController(make: CustomController.init)

        XCTAssertTrue(
            type(of: bridge) == UIKitViewController<CustomController>.self
        )
    }

    func testInstanceBridgeExtensionsPreserveConcreteTypes() {
        final class CustomView: UIView {}
        final class CustomController: UIViewController {}

        let viewBridge = CustomView().asSwiftUI()
        let controllerBridge = CustomController().asSwiftUI()

        XCTAssertTrue(type(of: viewBridge) == UIKitView<CustomView>.self)
        XCTAssertTrue(
            type(of: controllerBridge) == UIKitViewController<CustomController>.self
        )
    }
}
