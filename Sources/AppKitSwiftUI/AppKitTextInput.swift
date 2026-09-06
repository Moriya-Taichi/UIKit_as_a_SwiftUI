#if os(macOS)
import AppKit
import SwiftUI

/// Shared native text-field bridge. Use AppKitTextField, AppKitSecureField or AppKitSearchField.
@MainActor
public struct AppKitTextInput<Field: NSTextField>: NSViewRepresentable, AppKitViewConfiguring {
    public typealias AppKitViewType = Field
    private let make: @MainActor () -> Field
    private let placeholder: AppKitDisplayText
    @Binding private var text: String
    private let onSubmit: @MainActor () -> Void
    private var configure: @MainActor (Field) -> Void = { _ in }

    fileprivate init(make: @escaping @MainActor () -> Field, placeholder: AppKitDisplayText,
                     text: Binding<String>, onSubmit: @escaping @MainActor () -> Void) {
        self.make = make
        self.placeholder = placeholder
        _text = text
        self.onSubmit = onSubmit
    }

    public func makeCoordinator() -> AppKitTextInputCoordinator {
        AppKitTextInputCoordinator(text: $text)
    }

    public func makeNSView(context: Context) -> Field {
        let field = make()
        field.usesSingleLineMode = true
        // Enter is handled by the delegate so focus changes do not submit.
        updateNSView(field, context: context)
        return field
    }

    public func updateNSView(_ nsView: Field, context: Context) {
        let coordinator = context.coordinator
        coordinator.text = $text
        let submitActions = context.environment.appKitSubmitActions
        coordinator.submit = {
            onSubmit()
            submitActions()
        }
        coordinator.environment.update(nsView, environment: context.environment) { field in
            configure(field)
            field.placeholderString = placeholder.resolve(in: context.environment.locale)
            let editor = field.currentEditor() as? NSTextView
            if editor?.hasMarkedText() != true, field.stringValue != text {
                let selectedRange = editor?.selectedRange()
                field.stringValue = text
                if let editor, let selectedRange {
                    editor.setSelectedRange(clampedTextRange(selectedRange, length: (text as NSString).length))
                }
            }
        }
        nsView.delegate = coordinator
    }

    public static func dismantleNSView(_ nsView: Field, coordinator: AppKitTextInputCoordinator) {
        if nsView.delegate === coordinator { nsView.delegate = nil }
        coordinator.submit = {}
        coordinator.text = .constant("")
    }

    public func configureAppKit(_ body: @escaping @MainActor (Field) -> Void) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { field in previous(field); body(field) }
        return copy
    }
}

@MainActor
public final class AppKitTextInputCoordinator: NSObject, NSTextFieldDelegate {
    fileprivate let environment = AppKitEnvironmentState()
    fileprivate var text: Binding<String>
    fileprivate var submit: @MainActor () -> Void = {}

    fileprivate init(text: Binding<String>) { self.text = text }

    public func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField,
              (field.currentEditor() as? NSTextView)?.hasMarkedText() != true else { return }
        if text.wrappedValue != field.stringValue { text.wrappedValue = field.stringValue }
    }

    public func controlTextDidEndEditing(_ notification: Notification) {
        controlTextDidChange(notification)
    }

    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard commandSelector == #selector(NSResponder.insertNewline(_:)), !textView.hasMarkedText() else { return false }
        if let field = control as? NSTextField, text.wrappedValue != field.stringValue {
            text.wrappedValue = field.stringValue
        }
        submit()
        return true
    }
}

public typealias AppKitTextField = AppKitTextInput<NSTextField>
public typealias AppKitSecureField = AppKitTextInput<NSSecureTextField>
public typealias AppKitSearchField = AppKitTextInput<NSSearchField>

func clampedTextRange(_ range: NSRange, length: Int) -> NSRange {
    let location = min(range.location, length)
    return NSRange(location: location, length: min(range.length, length - location))
}
public extension AppKitTextInput where Field == NSTextField {
    init(_ placeholder: LocalizedStringResource, text: Binding<String>, onSubmit: @escaping @MainActor () -> Void = {}) {
        self.init(make: { NSTextField() }, placeholder: .localized(placeholder), text: text, onSubmit: onSubmit)
    }

    init(verbatim placeholder: String = "", text: Binding<String>, onSubmit: @escaping @MainActor () -> Void = {}) {
        self.init(make: { NSTextField() }, placeholder: .verbatim(placeholder), text: text, onSubmit: onSubmit)
    }
}
public extension AppKitTextInput where Field == NSSecureTextField {
    init(_ placeholder: LocalizedStringResource, text: Binding<String>, onSubmit: @escaping @MainActor () -> Void = {}) {
        self.init(make: { NSSecureTextField() }, placeholder: .localized(placeholder), text: text, onSubmit: onSubmit)
    }

    init(verbatim placeholder: String = "", text: Binding<String>, onSubmit: @escaping @MainActor () -> Void = {}) {
        self.init(make: { NSSecureTextField() }, placeholder: .verbatim(placeholder), text: text, onSubmit: onSubmit)
    }
}
public extension AppKitTextInput where Field == NSSearchField {
    init(_ placeholder: LocalizedStringResource, text: Binding<String>, onSubmit: @escaping @MainActor () -> Void = {}) {
        self.init(make: { NSSearchField() }, placeholder: .localized(placeholder), text: text, onSubmit: onSubmit)
    }

    init(verbatim placeholder: String = "", text: Binding<String>, onSubmit: @escaping @MainActor () -> Void = {}) {
        self.init(make: { NSSearchField() }, placeholder: .verbatim(placeholder), text: text, onSubmit: onSubmit)
    }
}
#endif
