import Observation
import SwiftUI
import UIKit

/// An observable model that owns the state and behavior of a bridged
/// `UITextView`, in the style of WebKit's `WebPage`.
///
/// The model owns the data (`text`), the desired focus (`isFocused`), the
/// observed editing state (`isEditing`), and the policy decisions supplied by
/// a `UIKitTextViewDeciding` value. `UIKitTextView` only displays the model:
/// it pushes model state into the UIKit view and forwards delegate callbacks
/// back into the model.
///
/// Notification-style delegate callbacks are delivered through `events`, which
/// is a single-consumer `AsyncStream`. Iterate it from exactly one task; a
/// second consumer competes for elements instead of receiving its own copy.
@available(iOS 17.0, macCatalyst 17.0, *)
@Observable @MainActor
public final class UIKitTextViewModel {
    /// Delegate-notification events, delivered through `events`.
    public enum Event: Equatable, Sendable {
        /// The view became first responder.
        case editingBegan
        /// The view's text changed, carrying the new value.
        case textChanged(String)
        /// The selection or caret moved, carrying the new selected range.
        case selectionChanged(NSRange)
        /// The view resigned first responder.
        case editingEnded
    }

    /// The view's text. Two-way: set it to update the attached view.
    public var text: String

    /// The desired focus. Two-way: set it to move first responder.
    public var isFocused: Bool

    /// Whether the view is currently editing. Read-only observation.
    public private(set) var isEditing: Bool

    /// The stream of delegate notifications for this model.
    ///
    /// The stream is single-consumer: iterate it from one task only.
    public let events: AsyncStream<Event>

    @ObservationIgnored
    private let eventContinuation: AsyncStream<Event>.Continuation

    @ObservationIgnored
    private let decider: (any UIKitTextViewDeciding)?

    /// Creates a model, optionally with a decider that answers policy
    /// questions. Without a decider every decision is allowed.
    public init(
        text: String = "",
        decider: (any UIKitTextViewDeciding)? = nil
    ) {
        self.text = text
        isFocused = false
        isEditing = false
        self.decider = decider
        let (stream, continuation) = AsyncStream.makeStream(of: Event.self)
        events = stream
        eventContinuation = continuation
    }

    deinit {
        eventContinuation.finish()
    }

    func handleEditingBegan() {
        if !isEditing {
            isEditing = true
        }
        if !isFocused {
            isFocused = true
        }
        eventContinuation.yield(.editingBegan)
    }

    func handleTextChanged(_ newText: String) {
        if text != newText {
            text = newText
        }
        eventContinuation.yield(.textChanged(newText))
    }

    func handleSelectionChanged(_ range: NSRange) {
        eventContinuation.yield(.selectionChanged(range))
    }

    func handleEditingEnded() {
        if isEditing {
            isEditing = false
        }
        if isFocused {
            isFocused = false
        }
        eventContinuation.yield(.editingEnded)
    }

    func shouldBeginEditing(_ textView: UITextView) -> Bool {
        decider?.shouldBeginEditing(textView) ?? true
    }

    func shouldEndEditing(_ textView: UITextView) -> Bool {
        decider?.shouldEndEditing(textView) ?? true
    }

    func shouldChangeText(
        in range: NSRange,
        replacement: String,
        textView: UITextView
    ) -> Bool {
        decider?.shouldChangeText(
            in: range,
            replacement: replacement,
            textView: textView
        ) ?? true
    }
}
