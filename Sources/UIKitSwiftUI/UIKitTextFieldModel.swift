import Observation
import SwiftUI
import UIKit

/// An observable model that owns the state and behavior of a bridged
/// `UITextField`, in the style of WebKit's `WebPage`.
///
/// The model owns the data (`text`), the desired focus (`isFocused`), the
/// observed editing state (`isEditing`), and the policy decisions supplied by
/// a `UIKitTextFieldDeciding` value. `UIKitTextField` only displays the model:
/// it pushes model state into the UIKit view and forwards delegate callbacks
/// back into the model.
///
/// Notification-style delegate callbacks are delivered through `events`, which
/// is a single-consumer `AsyncStream`. Iterate it from exactly one task; a
/// second consumer competes for elements instead of receiving its own copy.
@available(iOS 17.0, macCatalyst 17.0, *)
@Observable @MainActor
public final class UIKitTextFieldModel {
    /// Delegate-notification events, delivered through `events`.
    public enum Event: Equatable, Sendable {
        /// The field became first responder.
        case editingBegan
        /// The field's text changed, carrying the new value.
        case textChanged(String)
        /// The clear button emptied the field.
        case cleared
        /// The return key submitted the field's contents.
        case submitted
        /// The field resigned first responder.
        case editingEnded
    }

    /// The field's text. Two-way: set it to update the attached field.
    public var text: String

    /// The desired focus. Two-way: set it to move first responder.
    public var isFocused: Bool

    /// Whether the field is currently editing. Read-only observation.
    public private(set) var isEditing: Bool

    /// The stream of delegate notifications for this model.
    ///
    /// The stream is single-consumer: iterate it from one task only. It
    /// buffers at most the newest 64 unconsumed events and drops the oldest
    /// beyond that, so subscribe before the events matter.
    public let events: AsyncStream<Event>

    @ObservationIgnored
    private let eventContinuation: AsyncStream<Event>.Continuation

    @ObservationIgnored
    private let decider: (any UIKitTextFieldDeciding)?

    /// Creates a model, optionally with a decider that answers policy
    /// questions. Without a decider every decision is allowed.
    public init(
        text: String = "",
        decider: (any UIKitTextFieldDeciding)? = nil
    ) {
        self.text = text
        isFocused = false
        isEditing = false
        self.decider = decider
        let (stream, continuation) = AsyncStream.makeStream(
            of: Event.self,
            bufferingPolicy: .bufferingNewest(64)
        )
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

    func handleSubmitted() {
        eventContinuation.yield(.submitted)
    }

    func handleCleared() {
        if !text.isEmpty {
            text = ""
        }
        eventContinuation.yield(.cleared)
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

    func shouldBeginEditing(_ textField: UITextField) -> Bool {
        decider?.shouldBeginEditing(textField) ?? true
    }

    func shouldEndEditing(_ textField: UITextField) -> Bool {
        decider?.shouldEndEditing(textField) ?? true
    }

    func shouldChangeText(
        in range: NSRange,
        replacement: String,
        textField: UITextField
    ) -> Bool {
        decider?.shouldChangeText(
            in: range,
            replacement: replacement,
            textField: textField
        ) ?? true
    }

    func shouldClear(_ textField: UITextField) -> Bool {
        decider?.shouldClear(textField) ?? true
    }

    func shouldReturn(_ textField: UITextField) -> Bool {
        decider?.shouldReturn(textField) ?? true
    }
}
