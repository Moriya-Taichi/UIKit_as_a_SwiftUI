#if os(macOS)
import AppKit
import SwiftUI

/// A single-column native table with stable IDs and SwiftUI row content.
/// Use AppKitCoordinatedView<NSTableView, ...> for custom columns/data sources.
@MainActor
public struct AppKitTableView<ID: Hashable, RowContent: View>: NSViewRepresentable, AppKitViewConfiguring {
    public typealias AppKitViewType = NSTableView
    private let data: AppKitListData<ID, RowContent>
    private let selection: AppKitListSelection<ID>
    private let selectedIDs: Set<ID>
    private var configure: @MainActor (NSTableView) -> Void = { _ in }


    public init<Data: RandomAccessCollection>(_ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<ID?>? = nil,
                                             @ViewBuilder content: @escaping @MainActor (Data.Element) -> RowContent) {
        self.data = AppKitListData(data, id: id, content: content)
        self.selection = selection.map(AppKitListSelection.single) ?? .none
        selectedIDs = self.selection.ids
    }

    public init<Data: RandomAccessCollection>(_ data: Data, selection: Binding<ID?>? = nil,
                                             @ViewBuilder content: @escaping @MainActor (Data.Element) -> RowContent)
    where Data.Element: Identifiable, Data.Element.ID == ID {
        self.init(data, id: \.id, selection: selection, content: content)
    }

    public init<Data: RandomAccessCollection>(_ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<Set<ID>>,
                                             @ViewBuilder content: @escaping @MainActor (Data.Element) -> RowContent) {
        self.data = AppKitListData(data, id: id, content: content)
        self.selection = .multiple(selection)
        selectedIDs = self.selection.ids
    }

    public init<Data: RandomAccessCollection>(_ data: Data, selection: Binding<Set<ID>>,
                                             @ViewBuilder content: @escaping @MainActor (Data.Element) -> RowContent)
    where Data.Element: Identifiable, Data.Element.ID == ID {
        self.init(data, id: \.id, selection: selection, content: content)
    }

    public func makeCoordinator() -> AppKitTableCoordinator { AppKitTableCoordinator() }

    public func makeNSView(context: Context) -> AppKitManagedScrollView {
        let scroll = AppKitManagedScrollView()
        let table = NSTableView()
        table.autoresizingMask = [.width]
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("content"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.usesAutomaticRowHeights = true
        scroll.hasVerticalScroller = true
        scroll.documentView = table
        context.coordinator.table = table
        updateNSView(scroll, context: context)
        return scroll
    }

    public func updateNSView(_ nsView: AppKitManagedScrollView, context: Context) {
        let coordinator = context.coordinator
        guard let table = coordinator.table else { return }
        coordinator.synchronizing = true
        defer { coordinator.synchronizing = false }
        let storage: AppKitListStorage<ID, RowContent>
        if let existing = coordinator.storage as? AppKitListStorage<ID, RowContent> {
            storage = existing
        } else {
            storage = AppKitListStorage(content: data.content, environment: context.environment)
            coordinator.storage = storage
        }
        let changedIDs = storage.ids != data.ids
        storage.update(ids: data.ids, content: data.content, environment: context.environment)
        coordinator.rowCount = data.ids.count
        coordinator.rowView = { storage.view(at: $0) }
        coordinator.enabled = context.environment.isEnabled && selection.allowsSelection
        coordinator.onSelection = { indexes in
            let ids = Set(indexes.compactMap { data.ids.indices.contains($0) ? data.ids[$0] : nil })
            selection.setVisibleSelection(ids, visibleIDs: Set(data.ids))
        }
        configure(table)
        table.delegate = coordinator
        table.dataSource = coordinator
        table.allowsMultipleSelection = selection.allowsMultiple
        table.allowsEmptySelection = true
        nsView.allowsUserScrolling = context.environment.isScrollEnabled
        if changedIDs || table.numberOfRows != data.ids.count { table.reloadData() }
        let indexes = IndexSet(data.ids.indices.filter { selectedIDs.contains(data.ids[$0]) })
        if table.selectedRowIndexes != indexes { table.selectRowIndexes(indexes, byExtendingSelection: false) }
    }

    public static func dismantleNSView(_ nsView: AppKitManagedScrollView, coordinator: AppKitTableCoordinator) {
        if let table = coordinator.table {
            if table.delegate === coordinator { table.delegate = nil }
            if table.dataSource === coordinator { table.dataSource = nil }
        }
        coordinator.storage = nil
        coordinator.rowView = { _ in nil }
        coordinator.onSelection = { _ in }
    }

    public func configureAppKit(_ body: @escaping @MainActor (NSTableView) -> Void) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { table in previous(table); body(table) }
        return copy
    }
}

@MainActor
public final class AppKitTableCoordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    fileprivate weak var table: NSTableView?
    fileprivate var storage: AnyObject?
    fileprivate var rowCount = 0
    fileprivate var rowView: (Int) -> NSView? = { _ in nil }
    fileprivate var onSelection: (IndexSet) -> Void = { _ in }
    fileprivate var synchronizing = false
    fileprivate var enabled = true

    public func numberOfRows(in tableView: NSTableView) -> Int { rowCount }
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? { rowView(row) }
    public func selectionShouldChange(in tableView: NSTableView) -> Bool { enabled }
    public func tableViewSelectionDidChange(_ notification: Notification) {
        guard !synchronizing, enabled, let table else { return }
        onSelection(table.selectedRowIndexes)
    }
}
#endif
