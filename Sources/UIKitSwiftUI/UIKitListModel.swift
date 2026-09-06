#if canImport(UIKit)
import Observation
import SwiftUI
import UIKit

/// An observable model that owns list data and selection for bridged table
/// and collection views, in the style of WebKit's `WebPage`.
///
/// The model owns the data; callers never implement `UITableViewDataSource`
/// or `UICollectionViewDataSource`. `UIKitTableView` and `UIKitCollectionView`
/// only display the model: they translate `sections` into a diffable data
/// source snapshot and forward selection callbacks back into the model.
///
/// Items are their own diffable identifiers, so they must be unique across
/// the entire model, not merely within a section, and section identifiers
/// must be unique too. A duplicate is a programmer error: it trips an
/// assertion in debug builds and can crash the data source when applied.
/// Because the value is the identifier, an item whose value changes is a new
/// identifier and reads as a delete plus an insert rather than an in-place
/// update; carry stable identity inside the item type when in-place update
/// semantics are needed.
///
/// Selection notifications are delivered through `events`, which is a
/// single-consumer `AsyncStream`. Iterate it from exactly one task; a second
/// consumer competes for elements instead of receiving its own copy.
@available(iOS 17.0, macCatalyst 17.0, *)
// `@Observable` is safe here, unlike in `UIKitTextFieldModel`: a generic class
// is realized lazily and never appears in the ObjC class list, so the ObjC
// runtime cannot realize it on iOS 16 and trip over the stored
// `ObservationRegistrar` the macro injects. The non-generic text-input models
// hand-roll the macro's expansion for exactly that reason.
@Observable @MainActor
public final class UIKitListModel<
    SectionID: Hashable & Sendable,
    Item: Hashable & Sendable
> {
    /// One section of the list: an identifier and the items it contains.
    public struct Section: Equatable {
        /// The section's identity in the diffable snapshot.
        public var id: SectionID

        /// The section's items, in display order.
        public var items: [Item]

        /// Creates a section with the given identifier and items.
        public init(id: SectionID, items: [Item]) {
            self.id = id
            self.items = items
        }
    }

    /// Selection events, delivered through `events`.
    public enum Event: Equatable, Sendable {
        /// The item was selected in an attached view.
        case selected(Item)
        /// The item was deselected in an attached view.
        case deselected(Item)
    }

    /// The list data. Two-way: mutate it to update every attached view.
    ///
    /// Section identifiers must be unique, and items must be unique across
    /// every section: each item is its own diffable identifier.
    public var sections: [Section] {
        didSet {
            removeSelectionsMissingFromSections()
        }
    }

    /// The items currently selected in an attached view. Read-only
    /// observation: the bridges maintain it from their delegate callbacks.
    public private(set) var selectedItems: [Item]

    /// The stream of selection notifications for this model.
    ///
    /// The stream is single-consumer: iterate it from one task only. It
    /// buffers at most the newest 64 unconsumed events and drops the oldest
    /// beyond that, so subscribe before the events matter.
    public let events: AsyncStream<Event>

    @ObservationIgnored
    private let eventContinuation: AsyncStream<Event>.Continuation

    /// Creates a model that owns the given sections.
    public init(sections: [Section]) {
        self.sections = sections
        selectedItems = []
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

    func handleSelected(_ item: Item) {
        if !selectedItems.contains(item) {
            selectedItems.append(item)
        }
        eventContinuation.yield(.selected(item))
    }

    func handleDeselected(_ item: Item) {
        if let index = selectedItems.firstIndex(of: item) {
            selectedItems.remove(at: index)
        }
        eventContinuation.yield(.deselected(item))
    }

    private func removeSelectionsMissingFromSections() {
        let availableItems = Set(sections.flatMap(\.items))
        selectedItems.removeAll { !availableItems.contains($0) }
    }

    func snapshot() -> NSDiffableDataSourceSnapshot<SectionID, Item> {
        // Both the check and its message are `assert` autoclosures, so an
        // optimized build never walks the data.
        assert(identityViolation() == nil, identityViolation() ?? "")

        var snapshot = NSDiffableDataSourceSnapshot<SectionID, Item>()
        for section in sections {
            snapshot.appendSections([section.id])
            snapshot.appendItems(section.items, toSection: section.id)
        }
        return snapshot
    }

    /// The first violation of the diffable identity contract, or `nil` when
    /// the model satisfies it. Called only from `assert`.
    private func identityViolation() -> String? {
        var seenSections: Set<SectionID> = []
        var seenItems: Set<Item> = []
        for section in sections {
            guard seenSections.insert(section.id).inserted else {
                return """
                    UIKitListModel requires unique section identifiers; \
                    duplicate: \(section.id)
                    """
            }
            for item in section.items {
                guard seenItems.insert(item).inserted else {
                    return """
                        UIKitListModel requires globally unique items; \
                        duplicate: \(item)
                        """
                }
            }
        }
        return nil
    }
}

@available(iOS 17.0, macCatalyst 17.0, *)
public extension UIKitListModel where SectionID == Int {
    /// Creates a single-section model that owns the given items.
    ///
    /// The items land in one section identified by `0`, and must be unique:
    /// each item is its own diffable identifier.
    convenience init(items: [Item]) {
        self.init(sections: [Section(id: 0, items: items)])
    }

    /// The items of a single-section model.
    ///
    /// Reading returns the first section's items, or an empty array when the
    /// model has no sections. Writing replaces `sections` with one section
    /// identified by `0`. The items must be unique: each one is its own
    /// diffable identifier, so a changed value reads as a delete plus an
    /// insert rather than an in-place update.
    var items: [Item] {
        get { sections.first?.items ?? [] }
        set { sections = [Section(id: 0, items: newValue)] }
    }
}
#endif
