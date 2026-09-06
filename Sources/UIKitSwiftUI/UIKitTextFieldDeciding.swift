#if canImport(UIKit)
import UIKit

/// Policy decisions for a bridged text field.
///
/// Mirrors the role of WebKit's `WebPage.NavigationDeciding`: implement only
/// the decisions you care about. Every requirement has a permissive default,
/// so a conforming type opts into the checks it needs and inherits `true`
/// for the rest.
///
/// A decider is injected into `UIKitTextFieldModel` at initialization and
/// owned by that model; the bridge never talks to it directly.
@available(iOS 17.0, macCatalyst 17.0, *)
@MainActor
public protocol UIKitTextFieldDeciding {
    /// Decides whether the field may become first responder.
    func shouldBeginEditing(_ textField: UITextField) -> Bool

    /// Decides whether the field may resign first responder.
    func shouldEndEditing(_ textField: UITextField) -> Bool

    /// Decides whether an edit may be applied to the field's text.
    ///
    /// - Parameters:
    ///   - range: The range of existing text the edit replaces.
    ///   - replacement: The text proposed for that range.
    ///   - textField: The field being edited.
    func shouldChangeText(
        in range: NSRange,
        replacement: String,
        textField: UITextField
    ) -> Bool

    /// Decides whether the clear button may empty the field.
    func shouldClear(_ textField: UITextField) -> Bool

    /// Decides whether the return key is accepted as a submission.
    func shouldReturn(_ textField: UITextField) -> Bool
}

@available(iOS 17.0, macCatalyst 17.0, *)
public extension UIKitTextFieldDeciding {
    /// Allows editing to begin.
    func shouldBeginEditing(_ textField: UITextField) -> Bool { true }

    /// Allows editing to end.
    func shouldEndEditing(_ textField: UITextField) -> Bool { true }

    /// Allows every edit.
    func shouldChangeText(
        in range: NSRange,
        replacement: String,
        textField: UITextField
    ) -> Bool { true }

    /// Allows the clear button to empty the field.
    func shouldClear(_ textField: UITextField) -> Bool { true }

    /// Allows the return key to submit.
    func shouldReturn(_ textField: UITextField) -> Bool { true }
}
#endif
