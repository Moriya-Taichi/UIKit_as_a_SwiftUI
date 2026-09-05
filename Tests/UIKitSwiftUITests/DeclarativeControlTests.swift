import SwiftUI
import UIKit
import XCTest
@testable import UIKitSwiftUI

@MainActor
private final class ControlState: ObservableObject {
    @Published var disabled = false
    @Published var scrollDisabled = false
    @Published var lineLimit: Int? = 2
    @Published var text = "Initial"
    @Published var value: Double = 0.123456789
    @Published var segment = Segment.second
    @Published var segments: [Segment] = [.first, .second]
    @Published var submitValue = 1
    var submitted: [Int] = []

    enum Segment: String, Hashable { case first, second }
}

@MainActor
private struct ControlHarness: View {
    @ObservedObject var state: ControlState

    var body: some View {
        VStack {
            UIKitSlider(value: $state.value)
                .configureUIKit {
                    $0.isEnabled = false // The SwiftUI environment remains authoritative.
                    $0.accessibilityIdentifier = "slider"
                }
            UIKitSwitch(isOn: .constant(true))
                .configureUIKit {
                    $0.isEnabled = true // Configuration cannot override .disabled(true).
                    $0.accessibilityIdentifier = "locally-disabled"
                }
                .disabled(true)
            UIKitTextField(verbatim: "Name", text: $state.text)
                .textFieldBorderStyle(.roundedRect)
                .textFieldClearButtonMode(.whileEditing)
                .uiKitKeyboardType(.emailAddress)
                .configureUIKit { $0.accessibilityIdentifier = "field" }
                .padding()
            UIKitView(make: UILabel.init)
                .text(state.text)
                .configureUIKit { $0.accessibilityIdentifier = "label" }
            UIKitView(make: UIScrollView.init)
                .configureUIKit { $0.accessibilityIdentifier = "scroll" }
                .frame(height: 50)
            UIKitSegmentedControl(
                state.segments, selection: $state.segment, title: { $0.rawValue }
            )
            .configureUIKit { $0.accessibilityIdentifier = "segments" }
        }
        .disabled(state.disabled)
        .scrollDisabled(state.scrollDisabled)
        .lineLimit(state.lineLimit)
        .onUIKitSubmit { [value = state.submitValue] in
            state.submitted.append(value)
        }
    }
}

@MainActor
final class DeclarativeControlTests: XCTestCase {
    func testAncestorEnvironmentUpdatesNativeControlsAndPreservesLocalDisabledModifier() async throws {
        let state = ControlState()
        let host = BridgeTestHost(ControlHarness(state: state))
        defer { host.close() }
        let mounted = await waitForBridge { host.view(UISlider.self, id: "slider") != nil }
        XCTAssertTrue(mounted)
        let slider = try XCTUnwrap(host.view(UISlider.self, id: "slider"))
        let locallyDisabled = try XCTUnwrap(host.view(UISwitch.self, id: "locally-disabled"))
        let label = try XCTUnwrap(host.view(UILabel.self, id: "label"))
        let scroll = try XCTUnwrap(host.view(UIScrollView.self, id: "scroll"))
        let field = try XCTUnwrap(host.view(UITextField.self, id: "field"))
        XCTAssertEqual(field.borderStyle, .roundedRect)
        XCTAssertEqual(field.clearButtonMode, .whileEditing)
        XCTAssertEqual(field.keyboardType, .emailAddress)
        XCTAssertEqual(label.numberOfLines, 2)
        XCTAssertTrue(slider.isEnabled)
        XCTAssertFalse(locallyDisabled.isEnabled)

        state.disabled = true
        state.scrollDisabled = true
        let disabled = await waitForBridge { !slider.isEnabled && !scroll.isScrollEnabled }
        XCTAssertTrue(disabled)
        XCTAssertFalse(field.isEnabled)

        state.disabled = false
        state.scrollDisabled = false
        state.lineLimit = nil
        state.text = "Updated"
        let restored = await waitForBridge {
            slider.isEnabled && scroll.isScrollEnabled && label.numberOfLines == 0
                && label.text == "Updated" && field.text == "Updated"
        }
        XCTAssertTrue(restored)
        XCTAssertFalse(locallyDisabled.isEnabled)
        XCTAssertTrue(host.view(UISlider.self, id: "slider") === slider)
    }

    func testSliderDoesNotRoundSourceUntilUserChangesValue() async throws {
        let state = ControlState()
        let host = BridgeTestHost(ControlHarness(state: state))
        defer { host.close() }
        let mounted = await waitForBridge { host.view(UISlider.self, id: "slider") != nil }
        XCTAssertTrue(mounted)
        let slider = try XCTUnwrap(host.view(UISlider.self, id: "slider"))
        XCTAssertEqual(state.value, 0.123456789)
        slider.value = 0.75
        slider.sendActions(for: .valueChanged)
        XCTAssertEqual(state.value, 0.75)
    }

    func testSegmentIdentitySurvivesReordering() async throws {
        let state = ControlState()
        let host = BridgeTestHost(ControlHarness(state: state))
        defer { host.close() }
        let mounted = await waitForBridge { host.view(UISegmentedControl.self, id: "segments") != nil }
        XCTAssertTrue(mounted)
        let control = try XCTUnwrap(host.view(UISegmentedControl.self, id: "segments"))
        XCTAssertEqual(control.selectedSegmentIndex, 1)
        state.segments = [.second, .first]
        let reordered = await waitForBridge { control.selectedSegmentIndex == 0 }
        XCTAssertTrue(reordered)
        XCTAssertEqual(state.segment, .second)
        control.selectedSegmentIndex = 1
        control.sendActions(for: .valueChanged)
        XCTAssertEqual(state.segment, .first)
    }

    func testSubmitModifierWorksOnAncestorAndRefreshesItsCapture() async throws {
        let state = ControlState()
        let host = BridgeTestHost(ControlHarness(state: state))
        defer { host.close() }
        let mounted = await waitForBridge { host.view(UITextField.self, id: "field") != nil }
        XCTAssertTrue(mounted)
        let field = try XCTUnwrap(host.view(UITextField.self, id: "field"))
        XCTAssertEqual(field.delegate?.textFieldShouldReturn?(field), true)
        XCTAssertEqual(state.submitted, [1])

        state.submitValue = 2
        state.text = "After capture update"
        let updated = await waitForBridge { field.text == state.text }
        XCTAssertTrue(updated)
        XCTAssertEqual(field.delegate?.textFieldShouldReturn?(field), true)
        XCTAssertEqual(state.submitted, [1, 2])
    }

    func testModelSubmitDeliversBothModifierAndStream() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }
        let model = UIKitTextFieldModel()
        let state = ControlState()
        let host = BridgeTestHost(
            UIKitTextField(model: model)
                .configureUIKit { $0.accessibilityIdentifier = "model-submit" }
                .onUIKitSubmit { state.submitted.append(1) }
        )
        defer { host.close() }
        var received: UIKitTextFieldModel.Event?
        let subscription = Task { @MainActor in
            for await event in model.events {
                received = event
                break
            }
        }
        defer { subscription.cancel() }
        let mounted = await waitForBridge { host.view(UITextField.self, id: "model-submit") != nil }
        XCTAssertTrue(mounted)
        let field = try XCTUnwrap(host.view(UITextField.self, id: "model-submit"))
        XCTAssertEqual(field.delegate?.textFieldShouldReturn?(field), true)
        XCTAssertEqual(state.submitted, [1])
        let delivered = await waitForBridge { received == .submitted }
        XCTAssertTrue(delivered)
    }

    func testSubmitModifiersAccumulateFromParentToChild() async throws {
        let state = ControlState()
        let host = BridgeTestHost(
            VStack {
                UIKitTextField(text: .constant(""))
                    .configureUIKit { $0.accessibilityIdentifier = "nested-submit" }
                    .onUIKitSubmit { state.submitted.append(2) }
            }
            .onUIKitSubmit { state.submitted.append(1) }
        )
        defer { host.close() }
        let mounted = await waitForBridge { host.view(UITextField.self, id: "nested-submit") != nil }
        XCTAssertTrue(mounted)
        let field = try XCTUnwrap(host.view(UITextField.self, id: "nested-submit"))
        XCTAssertEqual(field.delegate?.textFieldShouldReturn?(field), true)
        XCTAssertEqual(state.submitted, [1, 2])
    }

    func testLegacyAndModernDatePickerArgumentsRemainUnambiguous() {
        _ = UIKitDatePicker(selection: .constant(Date()))
        _ = UIKitDatePicker(selection: .constant(Date()), displayedComponents: .date)
        _ = UIKitDatePicker(selection: .constant(Date()), mode: .time)
        _ = UIKitDatePicker("Birthday", selection: .constant(Date()), displayedComponents: [.date])
            .uiKitDatePickerStyle(.wheels)
        _ = UIKitButton(localized: "Save") {}
        _ = UIKitTextField(localized: "Name", text: .constant(""))
        _ = UIKitSearchBar(localizedPrompt: "Search", text: .constant(""))
    }
}
