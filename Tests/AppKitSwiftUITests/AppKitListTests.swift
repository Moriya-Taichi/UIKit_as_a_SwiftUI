#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import AppKitSwiftUI

private struct RowSuffixKey: EnvironmentKey { static let defaultValue = "" }
private extension EnvironmentValues {
    var rowSuffix: String {
        get { self[RowSuffixKey.self] }
        set { self[RowSuffixKey.self] = newValue }
    }
}

private struct Person: Identifiable {
    let id: Int
    var name: String
}

@MainActor
private final class ListState: ObservableObject {
    @Published var people = [Person(id: 1, name: "Alice"), Person(id: 2, name: "Bob")]
    @Published var selection: Set<Int> = [2]
    @Published var suffix = "!"
    @Published var disabled = false
}

@MainActor
private struct ListHarness: View {
    @ObservedObject var state: ListState
    var body: some View {
        VStack {
            AppKitTableView(state.people, selection: $state.selection) { person in
                AppKitView(make: { NSTextField(labelWithString: "") }, update: { field, context in
                    field.stringValue = person.name + context.environment.rowSuffix
                    field.identifier = NSUserInterfaceItemIdentifier("table-\(person.id)")
                })
            }.frame(width: 450, height: 140)
            AppKitCollectionView(state.people, selection: $state.selection, layout: {
                let layout = NSCollectionViewFlowLayout()
                layout.itemSize = NSSize(width: 200, height: 44)
                return layout
            }) { person in
                AppKitView(make: { NSTextField(labelWithString: "") }, update: { field, context in
                    field.stringValue = person.name + context.environment.rowSuffix
                    field.identifier = NSUserInterfaceItemIdentifier("collection-\(person.id)")
                })
            }.frame(width: 450, height: 140)
        }
        .environment(\.rowSuffix, state.suffix)
        .disabled(state.disabled)
    }
}

@MainActor
final class AppKitListTests: XCTestCase {
    func testStableIdentityContentEnvironmentAndSelectionAcrossFiltering() async throws {
        let state = ListState()
        let host = AppKitBridgeTestHost(ListHarness(state: state))
        defer { host.close() }
        try await waitForAppKit {
            host.find(NSTextField.self, id: "table-1")?.stringValue == "Alice!" &&
            host.find(NSTextField.self, id: "collection-1")?.stringValue == "Alice!"
        }
        let table = try XCTUnwrap(host.find(NSTableView.self))
        let collection = try XCTUnwrap(host.find(NSCollectionView.self))
        let oldTableRow = try XCTUnwrap(host.find(NSTextField.self, id: "table-1"))
        let oldCollectionItem = try XCTUnwrap(host.find(NSTextField.self, id: "collection-1"))
        XCTAssertEqual(table.selectedRowIndexes, IndexSet(integer: 1))
        XCTAssertEqual(collection.selectionIndexPaths, [IndexPath(item: 1, section: 0)])
        state.people[0].name = "Alicia"
        state.suffix = "?"
        try await waitForAppKit { oldTableRow.stringValue == "Alicia?" && oldCollectionItem.stringValue == "Alicia?" }
        XCTAssertTrue(host.find(NSTextField.self, id: "table-1") === oldTableRow)
        XCTAssertTrue(host.find(NSTextField.self, id: "collection-1") === oldCollectionItem)
        state.people.reverse()
        try await waitForAppKit { table.selectedRow == 0 && collection.selectionIndexPaths == [IndexPath(item: 0, section: 0)] }
        XCTAssertEqual(state.selection, [2])
        state.people.removeAll { $0.id == 2 }
        try await waitForAppKit { table.numberOfRows == 1 && table.selectedRow == -1 && collection.selectionIndexPaths.isEmpty }
        XCTAssertEqual(state.selection, [2])
        state.people.append(Person(id: 2, name: "Bob"))
        try await waitForAppKit { table.selectedRow == 1 && collection.selectionIndexPaths == [IndexPath(item: 1, section: 0)] }
        XCTAssertEqual(state.selection, [2])
        host.remove()
        try await waitForAppKit { table.delegate == nil && table.dataSource == nil && collection.delegate == nil && collection.dataSource == nil }
    }

    func testNativeSelectionWritesBindingsAndDisabledBlocksUserSelection() async throws {
        let state = ListState()
        let host = AppKitBridgeTestHost(ListHarness(state: state))
        defer { host.close() }
        try await waitForAppKit { host.find(NSTableView.self)?.numberOfRows == 2 }
        let table = try XCTUnwrap(host.find(NSTableView.self))
        let collection = try XCTUnwrap(host.find(NSCollectionView.self))
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        try await waitForAppKit { state.selection == [1] && collection.selectionIndexPaths == [IndexPath(item: 0, section: 0)] }
        collection.selectionIndexPaths = [IndexPath(item: 1, section: 0)]
        let delegate = try XCTUnwrap(collection.delegate as? AppKitCollectionCoordinator)
        delegate.collectionView(collection, didSelectItemsAt: [IndexPath(item: 1, section: 0)])
        try await waitForAppKit { state.selection == [2] && table.selectedRow == 1 }
        state.selection = []
        try await waitForAppKit { table.selectedRow == -1 && collection.selectionIndexPaths.isEmpty }
        state.disabled = true
        try await waitForAppKit { !collection.isSelectable }
        let tableDelegate = try XCTUnwrap(table.delegate as? AppKitTableCoordinator)
        XCTAssertFalse(tableDelegate.selectionShouldChange(in: table))
        XCTAssertTrue(delegate.collectionView(collection, shouldSelectItemsAt: [IndexPath(item: 0, section: 0)]).isEmpty)
    }

    func testAllDataInitializersAndFilteredMultipleSelectionSemantics() async {
        let data = [Person(id: 1, name: "A")]
        _ = AppKitTableView(data) { Text($0.name) }
        _ = AppKitTableView(data, selection: .constant(Optional(1))) { Text($0.name) }
        _ = AppKitTableView(data, id: \.id, selection: .constant(Set([1]))) { Text($0.name) }
        _ = AppKitCollectionView(data, layout: { NSCollectionViewFlowLayout() }) { Text($0.name) }
        _ = AppKitCollectionView(data, selection: .constant(Optional(1)), layout: { NSCollectionViewFlowLayout() }) { Text($0.name) }
        _ = AppKitCollectionView(data, id: \.id, selection: .constant(Set([1])), layout: { NSCollectionViewFlowLayout() }) { Text($0.name) }
        var selected: Set<Int> = [2, 99]
        let selection = AppKitListSelection.multiple(Binding(get: { selected }, set: { selected = $0 }))
        selection.setVisibleSelection([1], visibleIDs: [1, 2])
        XCTAssertEqual(selected, [1, 99])
    }
}
#endif
