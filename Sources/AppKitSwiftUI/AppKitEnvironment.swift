#if os(macOS)
import AppKit
import SwiftUI

@MainActor
final class AppKitEnvironmentState {
    private var textEditing: (editable: Bool, selectable: Bool)?

    func update<V: NSView>(
        _ view: V,
        environment: EnvironmentValues,
        configure: (V) -> Void
    ) {
        if let text = view as? NSTextView, let textEditing {
            text.isEditable = textEditing.editable
            text.isSelectable = textEditing.selectable
        }
        if let label = view as? NSTextField, !label.isEditable {
            label.maximumNumberOfLines = max(0, environment.lineLimit ?? 0)
        }
        configure(view)
        if let control = view as? NSControl {
            control.isEnabled = environment.isEnabled
        }
        if let text = view as? NSTextView {
            textEditing = (text.isEditable, text.isSelectable)
            text.isEditable = text.isEditable && environment.isEnabled
            text.isSelectable = text.isSelectable && environment.isEnabled
        }
        if let scroll = view as? AppKitManagedScrollView {
            scroll.allowsUserScrolling = environment.isScrollEnabled
        }
    }

    func dismantle() {}
}

/// A scroll view that honors `scrollDisabled` for wheel and scroller input.
/// Programmatic scrolling remains available, including selection visibility.
@MainActor
public class AppKitManagedScrollView: NSScrollView {
    public internal(set) var allowsUserScrolling = true {
        didSet { tile() }
    }

    public override func tile() {
        super.tile()
        // AppKit recalculates scroller availability while tiling. Apply the
        // environment restriction after each recalculation, including resize.
        if !allowsUserScrolling {
            verticalScroller?.isEnabled = false
            horizontalScroller?.isEnabled = false
        }
    }

    public override func scrollWheel(with event: NSEvent) {
        guard allowsUserScrolling else { return }
        super.scrollWheel(with: event)
    }
}

struct AppKitSubmitActions: Sendable {
    var actions: [@MainActor @Sendable () -> Void] = []

    @MainActor func callAsFunction() {
        for action in actions { action() }
    }
}

private struct AppKitSubmitKey: EnvironmentKey {
    static let defaultValue = AppKitSubmitActions()
}

extension EnvironmentValues {
    var appKitSubmitActions: AppKitSubmitActions {
        get { self[AppKitSubmitKey.self] }
        set { self[AppKitSubmitKey.self] = newValue }
    }
}

public extension View {
    /// Receives Return submissions from descendant AppKit text fields.
    /// Independent of SwiftUI's `onSubmit` and `submitScope`.
    func onAppKitSubmit(_ action: @escaping @MainActor @Sendable () -> Void) -> some View {
        transformEnvironment(\.appKitSubmitActions) { $0.actions.append(action) }
    }
}
#endif
