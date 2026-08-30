import SwiftUI
import UIKit
import XCTest
@testable import UIKitSwiftUI

@MainActor
final class ModuleTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertEqual(UIView().frame, .zero)
    }
}

