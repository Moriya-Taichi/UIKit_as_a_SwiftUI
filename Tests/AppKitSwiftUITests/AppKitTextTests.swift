#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import AppKitSwiftUI

@MainActor
private final class TextState: ObservableObject {
    @Published var text = "Initial"
    @Published var disabled = false
    @Published var lineLimit = 2
    var submitted: [String] = []
}

@MainActor
private struct TextHarness: View {
    @ObservedObject var state: TextState
    var body: some View {
        VStack {
            AppKitTextField(verbatim: "Name", text: $state.text, onSubmit: { state.submitted.append("initializer") })
                .setting(\.identifier, to: NSUserInterfaceItemIdentifier("input"))
                .padding()
                .onAppKitSubmit { state.submitted.append("child") }
            AppKitTextView(text: $state.text)
                .setting(\.identifier, to: NSUserInterfaceItemIdentifier("editor"))
            AppKitViewCatalog.label("A long label")
                .setting(\.identifier, to: NSUserInterfaceItemIdentifier("label"))
        }
        .lineLimit(state.lineLimit)
        .disabled(state.disabled)
        .scrollDisabled(state.disabled)
        .onAppKitSubmit { state.submitted.append("parent") }
    }
}

@MainActor
final class AppKitTextTests: XCTestCase {
    func testTextBindingSubmitPropagationAndEnvironment() async throws {
        let state = TextState()
        let host = AppKitBridgeTestHost(TextHarness(state: state))
        defer { host.close() }
        try await waitForAppKit { host.find(NSTextField.self, id: "input")?.stringValue == "Initial" }
        let field = try XCTUnwrap(host.find(NSTextField.self, id: "input"))
        let editor = try XCTUnwrap(host.find(NSTextView.self, id: "editor"))
        let delegate = try XCTUnwrap(field.delegate as? AppKitTextInputCoordinator)
        field.stringValue = "Typed"
        delegate.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        XCTAssertEqual(state.text, "Typed")
        XCTAssertTrue(delegate.control(field, textView: NSTextView(), doCommandBy: #selector(NSResponder.insertNewline(_:))))
        XCTAssertEqual(state.submitted, ["initializer", "parent", "child"])
        state.text = "External"
        try await waitForAppKit { field.stringValue == "External" && editor.string == "External" }
        state.disabled = true
        try await waitForAppKit { !field.isEnabled && !editor.isEditable }
        XCTAssertFalse(try XCTUnwrap(editor.enclosingScrollView as? AppKitManagedScrollView).allowsUserScrolling)
        state.disabled = false
        state.lineLimit = 3
        try await waitForAppKit { field.isEnabled && editor.isEditable && host.find(NSTextField.self, id: "label")?.maximumNumberOfLines == 3 }
        host.remove()
        try await waitForAppKit { field.delegate == nil && editor.delegate == nil }
    }

    func testTextEditorDefersBindingWritesDuringMarkedTextAndClampsSelection() async throws {
        let state = TextState()
        let host = AppKitBridgeTestHost(TextHarness(state: state))
        defer { host.close() }
        try await waitForAppKit { host.find(NSTextView.self, id: "editor")?.string == "Initial" }
        let editor = try XCTUnwrap(host.find(NSTextView.self, id: "editor"))
        let delegate = try XCTUnwrap(editor.delegate as? AppKitTextView.Coordinator)
        editor.setSelectedRange(NSRange(location: 0, length: editor.string.utf16.count))
        editor.setMarkedText("にほん", selectedRange: NSRange(location: 3, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertTrue(editor.hasMarkedText())
        delegate.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
        XCTAssertEqual(state.text, "Initial")
        editor.unmarkText()
        delegate.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
        XCTAssertEqual(state.text, editor.string)
        editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
        state.text = "短"
        try await waitForAppKit { editor.string == "短" }
        XCTAssertLessThanOrEqual(editor.selectedRange().location, 1)
    }
}
#endif
