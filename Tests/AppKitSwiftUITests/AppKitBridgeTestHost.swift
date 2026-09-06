#if os(macOS)
import AppKit
import SwiftUI
import XCTest

@MainActor
final class AppKitBridgeTestHost {
    let window: NSWindow
    let hosting: NSHostingView<AnyView>

    init<Content: View>(_ content: Content) {
        _ = NSApplication.shared
        hosting = NSHostingView(rootView: AnyView(content))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.orderFront(nil)
        hosting.layoutSubtreeIfNeeded()
    }

    func remove() { hosting.rootView = AnyView(EmptyView()) }
    func close() { window.orderOut(nil); window.contentView = nil; window.close() }

    func find<V: NSView>(_ type: V.Type, id: String? = nil) -> V? {
        func descend(_ view: NSView) -> V? {
            if let found = view as? V, id == nil || found.identifier?.rawValue == id { return found }
            for child in view.subviews {
                if let found = descend(child) { return found }
            }
            return nil
        }
        return descend(hosting)
    }
}

@MainActor
func waitForAppKit(_ condition: @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
    for _ in 0..<300 {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    XCTFail("AppKit view did not reach expected state", file: file, line: line)
}
#endif
