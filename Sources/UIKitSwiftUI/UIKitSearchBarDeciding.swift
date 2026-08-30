import UIKit

/// Policy decisions for a bridged search bar.
///
/// Mirrors the role of WebKit's `WebPage.NavigationDeciding`: implement only
/// the decisions you care about. Every requirement has a permissive default,
/// so a conforming type opts into the checks it needs and inherits `true`
/// for the rest.
///
/// A decider is injected into `UIKitSearchBarModel` at initialization and
/// owned by that model; the bridge never talks to it directly.
@available(iOS 17.0, macCatalyst 17.0, *)
@MainActor
public protocol UIKitSearchBarDeciding {
    /// Decides whether the search bar may begin editing.
    func shouldBeginEditing(_ searchBar: UISearchBar) -> Bool

    /// Decides whether the search bar may end editing.
    func shouldEndEditing(_ searchBar: UISearchBar) -> Bool

    /// Decides whether an edit may be applied to the query text.
    ///
    /// - Parameters:
    ///   - range: The range of existing text the edit replaces.
    ///   - replacement: The text proposed for that range.
    ///   - searchBar: The search bar being edited.
    func shouldChangeText(
        in range: NSRange,
        replacement: String,
        searchBar: UISearchBar
    ) -> Bool
}

@available(iOS 17.0, macCatalyst 17.0, *)
public extension UIKitSearchBarDeciding {
    /// Allows editing to begin.
    func shouldBeginEditing(_ searchBar: UISearchBar) -> Bool { true }

    /// Allows editing to end.
    func shouldEndEditing(_ searchBar: UISearchBar) -> Bool { true }

    /// Allows every edit.
    func shouldChangeText(
        in range: NSRange,
        replacement: String,
        searchBar: UISearchBar
    ) -> Bool { true }
}
