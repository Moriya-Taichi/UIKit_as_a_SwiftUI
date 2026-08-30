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
}
