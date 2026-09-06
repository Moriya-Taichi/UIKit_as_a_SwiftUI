#if os(macOS)
import AppKit
import SwiftUI

/// A single-section native collection with a caller-supplied layout and SwiftUI items.
@MainActor
public struct AppKitCollectionView<ID: Hashable, ItemContent: View>: NSViewRepresentable, AppKitViewConfiguring {
    public typealias AppKitViewType = NSCollectionView
    private let data: AppKitListData<ID, ItemContent>
    private let selection: AppKitListSelection<ID>
    private let selectedIDs: Set<ID>
    private let layout: @MainActor () -> NSCollectionViewLayout
    private var configure: @MainActor (NSCollectionView) -> Void = { _ in }


    public init<Data: RandomAccessCollection>(_ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<ID?>? = nil, layout: @escaping @MainActor () -> NSCollectionViewLayout,
                                             @ViewBuilder content: @escaping @MainActor (Data.Element) -> ItemContent) {
        self.data = AppKitListData(data, id: id, content: content)
        self.selection = selection.map(AppKitListSelection.single) ?? .none
        selectedIDs = self.selection.ids
        self.layout = layout
    }

    public init<Data: RandomAccessCollection>(_ data: Data, selection: Binding<ID?>? = nil, layout: @escaping @MainActor () -> NSCollectionViewLayout,
                                             @ViewBuilder content: @escaping @MainActor (Data.Element) -> ItemContent)
    where Data.Element: Identifiable, Data.Element.ID == ID {
        self.init(data, id: \.id, selection: selection, layout: layout, content: content)
    }

    public init<Data: RandomAccessCollection>(_ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<Set<ID>>, layout: @escaping @MainActor () -> NSCollectionViewLayout,
                                             @ViewBuilder content: @escaping @MainActor (Data.Element) -> ItemContent) {
        self.data = AppKitListData(data, id: id, content: content)
        self.selection = .multiple(selection)
        selectedIDs = self.selection.ids
        self.layout = layout
    }

    public init<Data: RandomAccessCollection>(_ data: Data, selection: Binding<Set<ID>>, layout: @escaping @MainActor () -> NSCollectionViewLayout,
                                             @ViewBuilder content: @escaping @MainActor (Data.Element) -> ItemContent)
    where Data.Element: Identifiable, Data.Element.ID == ID {
        self.init(data, id: \.id, selection: selection, layout: layout, content: content)
    }

    public func makeCoordinator() -> AppKitCollectionCoordinator { AppKitCollectionCoordinator() }

    public func makeNSView(context: Context) -> AppKitManagedScrollView {
        let scroll = AppKitManagedScrollView()
        let collection = NSCollectionView()
        collection.autoresizingMask = [.width]
        collection.collectionViewLayout = layout()
        collection.register(AppKitHostingCollectionItem.self, forItemWithIdentifier: AppKitCollectionCoordinator.itemIdentifier)
        scroll.hasVerticalScroller = true
        scroll.documentView = collection
        context.coordinator.collection = collection
        updateNSView(scroll, context: context)
        return scroll
    }

    public func updateNSView(_ nsView: AppKitManagedScrollView, context: Context) {
        let coordinator = context.coordinator
        guard let collection = coordinator.collection else { return }
        coordinator.synchronizing = true
        defer { coordinator.synchronizing = false }
        let storage: AppKitListStorage<ID, ItemContent>
        if let existing = coordinator.storage as? AppKitListStorage<ID, ItemContent> {
            storage = existing
        } else {
            storage = AppKitListStorage(content: data.content, environment: context.environment)
            coordinator.storage = storage
        }
        let changedIDs = storage.ids != data.ids
        storage.update(ids: data.ids, content: data.content, environment: context.environment)
        coordinator.itemCount = data.ids.count
        coordinator.itemView = { storage.view(at: $0) }
        coordinator.enabled = context.environment.isEnabled && selection.allowsSelection
        coordinator.onSelection = { paths in
            let ids = Set(paths.compactMap { data.ids.indices.contains($0.item) ? data.ids[$0.item] : nil })
            selection.setVisibleSelection(ids, visibleIDs: Set(data.ids))
        }
        configure(collection)
        collection.delegate = coordinator
        collection.dataSource = coordinator
        collection.isSelectable = coordinator.enabled
        collection.allowsMultipleSelection = selection.allowsMultiple
        collection.allowsEmptySelection = true
        nsView.allowsUserScrolling = context.environment.isScrollEnabled
        if changedIDs { collection.reloadData() }
        let paths = Set(data.ids.indices.filter { selectedIDs.contains(data.ids[$0]) }.map { IndexPath(item: $0, section: 0) })
        if collection.selectionIndexPaths != paths { collection.selectionIndexPaths = paths }
    }

    public static func dismantleNSView(_ nsView: AppKitManagedScrollView, coordinator: AppKitCollectionCoordinator) {
        if let collection = coordinator.collection {
            if collection.delegate === coordinator { collection.delegate = nil }
            if collection.dataSource === coordinator { collection.dataSource = nil }
        }
        coordinator.storage = nil
        coordinator.itemView = { _ in nil }
        coordinator.onSelection = { _ in }
    }

    public func configureAppKit(_ body: @escaping @MainActor (NSCollectionView) -> Void) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { collection in previous(collection); body(collection) }
        return copy
    }
}

@MainActor
final class AppKitHostingCollectionItem: NSCollectionViewItem {
    override func loadView() {
        let box = NSBox()
        box.boxType = .custom
        box.borderType = .noBorder
        box.contentViewMargins = .zero
        box.fillColor = .clear
        view = box
    }

    override var isSelected: Bool {
        didSet { (view as? NSBox)?.fillColor = isSelected ? .selectedContentBackgroundColor : .clear }
    }

    func install(_ content: NSView?) { (view as? NSBox)?.contentView = content }
}

@MainActor
public final class AppKitCollectionCoordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
    fileprivate static let itemIdentifier = NSUserInterfaceItemIdentifier("AppKitSwiftUI.item")
    fileprivate weak var collection: NSCollectionView?
    fileprivate var storage: AnyObject?
    fileprivate var itemCount = 0
    fileprivate var itemView: (Int) -> NSView? = { _ in nil }
    fileprivate var onSelection: (Set<IndexPath>) -> Void = { _ in }
    fileprivate var synchronizing = false
    fileprivate var enabled = true

    public func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int { itemCount }
    public func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: Self.itemIdentifier, for: indexPath)
        (item as? AppKitHostingCollectionItem)?.install(itemView(indexPath.item))
        return item
    }

    public func collectionView(_ collectionView: NSCollectionView, shouldSelectItemsAt indexPaths: Set<IndexPath>) -> Set<IndexPath> {
        enabled ? indexPaths : []
    }

    public func collectionView(_ collectionView: NSCollectionView, shouldDeselectItemsAt indexPaths: Set<IndexPath>) -> Set<IndexPath> {
        enabled ? indexPaths : []
    }

    public func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) { changed(collectionView) }
    public func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) { changed(collectionView) }

    private func changed(_ collection: NSCollectionView) {
        guard !synchronizing, enabled else { return }
        onSelection(collection.selectionIndexPaths)
    }
}
#endif
