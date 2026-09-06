#if canImport(UIKit)
import UIKit

/// Policy decisions for a bridged text view.
///
/// Mirrors the role of WebKit's `WebPage.NavigationDeciding`: implement only
/// the decisions you care about. Every requirement has a permissive default,
/// so a conforming type opts into the checks it needs and inherits `true`
/// for the rest.
///
/// A decider is injected into `UIKitTextViewModel` at initialization and
/// owned by that model; the bridge never talks to it directly.
@available(iOS 17.0, macCatalyst 17.0, *)
@MainActor
public protocol UIKitTextViewDeciding {
    /// Decides whether the view may become first responder.
    func shouldBeginEditing(_ textView: UITextView) -> Bool

    /// Decides whether the view may resign first responder.
    func shouldEndEditing(_ textView: UITextView) -> Bool

    /// Decides whether an edit may be applied to the view's text.
    ///
    /// - Parameters:
    ///   - range: The range of existing text the edit replaces.
    ///   - replacement: The text proposed for that range.
    ///   - textView: The view being edited.
    func shouldChangeText(
        in range: NSRange,
        replacement: String,
        textView: UITextView
    ) -> Bool
}

@available(iOS 17.0, macCatalyst 17.0, *)
public extension UIKitTextViewDeciding {
    /// Allows editing to begin.
    func shouldBeginEditing(_ textView: UITextView) -> Bool { true }

    /// Allows editing to end.
    func shouldEndEditing(_ textView: UITextView) -> Bool { true }

    /// Allows every edit.
    func shouldChangeText(
        in range: NSRange,
        replacement: String,
        textView: UITextView
    ) -> Bool { true }
}
#endif
