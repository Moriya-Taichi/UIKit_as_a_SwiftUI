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
/// Selection notifications are delivered through `events`, which is a
/// single-consumer `AsyncStream`. Iterate it from exactly one task; a second
/// consumer competes for elements instead of receiving its own copy.
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
    public var sections: [Section]

    /// The items currently selected in an attached view. Read-only
    /// observation: the bridges maintain it from their delegate callbacks.
    public private(set) var selectedItems: [Item]

    /// The stream of selection notifications for this model.
    ///
    /// The stream is single-consumer: iterate it from one task only.
    public let events: AsyncStream<Event>

    @ObservationIgnored
    private let eventContinuation: AsyncStream<Event>.Continuation

    /// Creates a model that owns the given sections.
    public init(sections: [Section]) {
        self.sections = sections
        selectedItems = []
        let (stream, continuation) = AsyncStream.makeStream(of: Event.self)
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

    func snapshot() -> NSDiffableDataSourceSnapshot<SectionID, Item> {
        var snapshot = NSDiffableDataSourceSnapshot<SectionID, Item>()
        for section in sections {
            snapshot.appendSections([section.id])
            snapshot.appendItems(section.items, toSection: section.id)
        }
        return snapshot
    }
}

public extension UIKitListModel where SectionID == Int {
    /// Creates a single-section model that owns the given items.
    ///
    /// The items land in one section identified by `0`.
    convenience init(items: [Item]) {
        self.init(sections: [Section(id: 0, items: items)])
    }

    /// The items of a single-section model.
    ///
    /// Reading returns the first section's items, or an empty array when the
    /// model has no sections. Writing replaces `sections` with one section
    /// identified by `0`.
    var items: [Item] {
        get { sections.first?.items ?? [] }
        set { sections = [Section(id: 0, items: newValue)] }
    }
}
