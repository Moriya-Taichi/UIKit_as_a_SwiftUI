#if os(macOS)
import AppKit
import SwiftUI

/// A plain-text editor with IME-aware Binding synchronization and native scrolling.
@MainActor
public struct AppKitTextView: NSViewRepresentable, AppKitViewConfiguring {
    public typealias AppKitViewType = NSTextView
    @Binding private var text: String
    private var configure: @MainActor (NSTextView) -> Void

    public init(text: Binding<String>, configure: @escaping @MainActor (NSTextView) -> Void = { _ in }) {
        _text = text
        self.configure = configure
    }

    @MainActor
    public final class Coordinator: NSObject, NSTextViewDelegate {
        fileprivate let environment = AppKitEnvironmentState()
        fileprivate var text: Binding<String>
        fileprivate var synchronizing = false
        fileprivate weak var editor: NSTextView?

        fileprivate init(text: Binding<String>) { self.text = text }

        public func textDidChange(_ notification: Notification) {
            guard !synchronizing, let editor = notification.object as? NSTextView, !editor.hasMarkedText() else { return }
            if text.wrappedValue != editor.string { text.wrappedValue = editor.string }
        }

        public func textDidEndEditing(_ notification: Notification) { textDidChange(notification) }
    }

    public func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    public func makeNSView(context: Context) -> AppKitManagedScrollView {
        let scroll = AppKitManagedScrollView()
        let editor = NSTextView(frame: .zero)
        editor.isRichText = false
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        scroll.hasVerticalScroller = true
        scroll.documentView = editor
        context.coordinator.editor = editor
        updateNSView(scroll, context: context)
        return scroll
    }

    public func updateNSView(_ nsView: AppKitManagedScrollView, context: Context) {
        guard let editor = context.coordinator.editor else { return }
        let coordinator = context.coordinator
        coordinator.text = $text
        coordinator.synchronizing = true
        defer { coordinator.synchronizing = false }
        coordinator.environment.update(editor, environment: context.environment, configure: configure)
        nsView.allowsUserScrolling = context.environment.isScrollEnabled
        if !editor.hasMarkedText(), editor.string != text {
            let selection = editor.selectedRange()
            editor.string = text
            editor.setSelectedRange(clampedTextRange(selection, length: (text as NSString).length))
        }
        editor.delegate = coordinator
    }

    public static func dismantleNSView(_ nsView: AppKitManagedScrollView, coordinator: Coordinator) {
        if let editor = coordinator.editor, editor.delegate === coordinator { editor.delegate = nil }
        coordinator.editor = nil
        coordinator.text = .constant("")
    }

    public func configureAppKit(_ body: @escaping @MainActor (NSTextView) -> Void) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { editor in previous(editor); body(editor) }
        return copy
    }
}
#endif
