#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import AppKitSwiftUI

@MainActor
final class AppKitModuleTests: XCTestCase {
    func testGenericBridgesAndDeclarativeControlsCompile() async {
        final class CustomView: NSView {}
        let bridge = AppKitView(make: { CustomView() })
        XCTAssertTrue(type(of: bridge) == AppKitView<CustomView>.self)
        _ = bridge.measuringWithAutoLayout().configureAppKit { $0.alphaValue = 0.5 }
        _ = AppKitViewController(make: { NSViewController() })
        _ = AppKitCoordinatedView(makeCoordinator: { NSObject() }, make: { _, _ in NSView() })
        _ = AppKitCoordinatedViewController(makeCoordinator: { NSObject() }, make: { _, _ in NSViewController() })
        _ = AppKitBridge.view(NSTextField(labelWithString: "Hello"))
        _ = Text("Hello").hostedInAppKit()
        _ = AppKitSlider(value: .constant(0.5)).sliderContinuousUpdates(false)
        _ = AppKitSlider(value: .constant(Float(0.5)))
        _ = AppKitStepper(value: .constant(2))
        _ = AppKitStepper(value: .constant(2.5))
        _ = AppKitToggle("Enabled", isOn: .constant(true))
        _ = AppKitSwitch(isOn: .constant(false))
        _ = AppKitSegmentedControl(["a", "b"], selection: .constant("a"), title: { $0 })
        _ = AppKitDatePicker("Date", selection: .constant(Date()), displayedComponents: [.date])
            .appKitDatePickerStyle(.textFieldAndStepper)
        _ = AppKitTextField("Name", text: .constant(""))
        _ = AppKitSecureField("Password", text: .constant(""))
        _ = AppKitSearchField("Search", text: .constant(""))
        _ = AppKitTextView(text: .constant(""))
    }
}
#endif
