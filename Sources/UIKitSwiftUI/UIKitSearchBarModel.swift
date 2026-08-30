import Observation
import SwiftUI
import UIKit

/// An observable model that owns the state and behavior of a bridged
/// `UISearchBar`, in the style of WebKit's `WebPage`.
///
/// The model owns the data (`text`), the desired focus (`isFocused`), the
/// observed editing state (`isEditing`), and the policy decisions supplied by
/// a `UIKitSearchBarDeciding` value. `UIKitSearchBar` only displays the model:
/// it pushes model state into the UIKit view and forwards delegate callbacks
/// back into the model.
///
/// Notification-style delegate callbacks are delivered through `events`, which
/// is a single-consumer `AsyncStream`. Iterate it from exactly one task; a
/// second consumer competes for elements instead of receiving its own copy.
@Observable @MainActor
public final class UIKitSearchBarModel {
    /// Delegate-notification events, delivered through `events`.
    public enum Event: Equatable, Sendable {
        /// The search bar began editing.
        case editingBegan
        /// The query text changed, carrying the new value.
        case textChanged(String)
        /// The search button submitted the query.
        case submitted
        /// The cancel button was tapped. The query text is left untouched;
        /// clear it yourself if that is the behavior you want.
        case cancelled
        /// The search bar ended editing.
        case editingEnded
    }

    /// The query text. Two-way: set it to update the attached search bar.
    public var text: String

    /// The desired focus. Two-way: set it to move first responder.
    public var isFocused: Bool

    /// Whether the search bar is currently editing. Read-only observation.
    public private(set) var isEditing: Bool

    /// The stream of delegate notifications for this model.
    ///
    /// The stream is single-consumer: iterate it from one task only.
    public let events: AsyncStream<Event>

    @ObservationIgnored
    private let eventContinuation: AsyncStream<Event>.Continuation

    @ObservationIgnored
    private let decider: (any UIKitSearchBarDeciding)?

    /// Creates a model, optionally with a decider that answers policy
    /// questions. Without a decider every decision is allowed.
    public init(
        text: String = "",
        decider: (any UIKitSearchBarDeciding)? = nil
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

    func handleSubmitted() {
        eventContinuation.yield(.submitted)
    }

    func handleCancelled() {
        eventContinuation.yield(.cancelled)
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

    func shouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        decider?.shouldBeginEditing(searchBar) ?? true
    }

    func shouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        decider?.shouldEndEditing(searchBar) ?? true
    }

    func shouldChangeText(
        in range: NSRange,
        replacement: String,
        searchBar: UISearchBar
    ) -> Bool {
        decider?.shouldChangeText(
            in: range,
            replacement: replacement,
            searchBar: searchBar
        ) ?? true
    }
}
