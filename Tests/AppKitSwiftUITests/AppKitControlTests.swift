#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import AppKitSwiftUI

@MainActor
private final class ControlState: ObservableObject {
    @Published var disabled = false
    @Published var revision = 1
    @Published var value = 0.123456789012345
    @Published var selection = "b"
    @Published var values = ["a", "b"]
    var received: [Int] = []
}

@MainActor
private final class OriginalTarget: NSObject {
    @objc func action(_ sender: NSControl) {}
}

@MainActor
private struct ControlHarness: View {
    @ObservedObject var state: ControlState
    let button: NSButton
    var body: some View {
        let revision = state.revision
        VStack {
            AppKitControl(make: { button }, update: { control, _ in control.title = "Revision \(revision)" },
                          onEvent: { _ in state.received.append(revision) })
            AppKitSlider(value: $state.value)
                .setting(\.identifier, to: NSUserInterfaceItemIdentifier("slider"))
            AppKitSegmentedControl(state.values, selection: $state.selection, title: { $0 })
                .setting(\.identifier, to: NSUserInterfaceItemIdentifier("segments"))
            AppKitSwitch(isOn: .constant(true)).disabled(true)
                .id("localDisabled")
        }
        .disabled(state.disabled)
    }
}

@MainActor
final class AppKitControlTests: XCTestCase {
    func testActionUsesLatestClosureAndRestoresOriginalTargetOnDismantle() async throws {
        let state = ControlState()
        let original = OriginalTarget()
        let button = NSButton(title: "Original", target: original, action: #selector(OriginalTarget.action(_:)))
        let host = AppKitBridgeTestHost(ControlHarness(state: state, button: button))
        defer { host.close() }
        try await waitForAppKit { button.title == "Revision 1" && button.target !== original }
        XCTAssertTrue(button.sendAction(button.action, to: button.target))
        XCTAssertEqual(state.received, [1])
        state.revision = 2
        try await waitForAppKit { button.title == "Revision 2" }
        XCTAssertTrue(button.sendAction(button.action, to: button.target))
        XCTAssertEqual(state.received, [1, 2])
        state.disabled = true
        try await waitForAppKit { !button.isEnabled }
        state.disabled = false
        try await waitForAppKit { button.isEnabled }
        XCTAssertFalse(try XCTUnwrap(host.find(NSSwitch.self)).isEnabled)
        host.remove()
        try await waitForAppKit { button.target === original }
        XCTAssertEqual(button.action, #selector(OriginalTarget.action(_:)))
    }

    func testDoublePrecisionAndValueBasedSegmentReordering() async throws {
        let state = ControlState()
        let host = AppKitBridgeTestHost(ControlHarness(state: state, button: NSButton()))
        defer { host.close() }
        try await waitForAppKit { host.find(NSSlider.self, id: "slider") != nil }
        let slider = try XCTUnwrap(host.find(NSSlider.self, id: "slider"))
        XCTAssertEqual(state.value, 0.123456789012345)
        XCTAssertEqual(slider.doubleValue, state.value)
        slider.doubleValue = 0.876543210987654
        XCTAssertTrue(slider.sendAction(slider.action, to: slider.target))
        XCTAssertEqual(state.value, 0.876543210987654)
        let segments = try XCTUnwrap(host.find(NSSegmentedControl.self, id: "segments"))
        XCTAssertEqual(segments.selectedSegment, 1)
        state.values = ["b", "a"]
        try await waitForAppKit { segments.label(forSegment: 0) == "b" }
        XCTAssertEqual(segments.selectedSegment, 0)
        segments.selectedSegment = 1
        XCTAssertTrue(segments.sendAction(segments.action, to: segments.target))
        XCTAssertEqual(state.selection, "a")
    }

    func testGenericAndCoordinatedViewTeardown() async throws {
        final class Token {}
        let token = Token()
        var tornDown = false
        let native = NSView()
        let host = AppKitBridgeTestHost(AppKitCoordinatedView(
            makeCoordinator: { token }, make: { _, _ in native },
            dismantle: { view, received in
                XCTAssertTrue(view === native)
                XCTAssertTrue(received === token)
                tornDown = true
            }))
        defer { host.close() }
        try await waitForAppKit { native.window != nil }
        host.remove()
        try await waitForAppKit { tornDown }
    }
}
#endif
