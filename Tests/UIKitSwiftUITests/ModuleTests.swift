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

    func testControlBridgePreservesConcreteControlType() {
        final class CustomControl: UIControl {}

        let bridge = UIKitControl(
            make: CustomControl.init,
            events: .valueChanged
        )

        XCTAssertTrue(
            type(of: bridge) == UIKitControl<CustomControl>.self
        )
    }

    func testBoundControlsExposeSwiftUIViews() {
        let slider = UIKitSlider(value: .constant(0.5))
        let toggle = UIKitSwitch(isOn: .constant(true))
        let stepper = UIKitStepper(value: .constant(2))
        let pages = UIKitPageControl(
            currentPage: .constant(1),
            numberOfPages: 3
        )
        let segments = UIKitSegmentedControl(
            ["First", "Second"],
            selection: .constant(0)
        )

        XCTAssertNotNil(type(of: slider))
        XCTAssertNotNil(type(of: toggle))
        XCTAssertNotNil(type(of: stepper))
        XCTAssertNotNil(type(of: pages))
        XCTAssertNotNil(type(of: segments))
    }

    func testTextFieldAcceptsTextAndFocusBindings() {
        let textField = UIKitTextField(
            "Placeholder",
            text: .constant("Value"),
            isFocused: .constant(false)
        )

        XCTAssertNotNil(type(of: textField))
    }
}
