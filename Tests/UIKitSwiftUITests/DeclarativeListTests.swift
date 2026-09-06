#if canImport(UIKit)
import SwiftUI
import UIKit
import XCTest
@testable import UIKitSwiftUI

// Deliberately not Hashable: editable display data is not a diffable identifier.
private struct Person: Identifiable {
    let id: Int
    var name: String
}

private struct RowMarkerKey: EnvironmentKey {
    static let defaultValue = "default"
}

private extension EnvironmentValues {
    var rowMarker: String {
        get { self[RowMarkerKey.self] }
        set { self[RowMarkerKey.self] = newValue }
    }
}

@MainActor
private final class ListState: ObservableObject {
    @Published var people = [Person(id: 1, name: "First"), Person(id: 2, name: "Second")]
    @Published var selectedIDs: Set<Int> = [2]
    @Published var selectedID: Int? = 2
    @Published var marker = "inherited"
}

@MainActor
private struct PersonRow: View {
    let person: Person
    let prefix: String
    @Environment(\.rowMarker) private var marker

    var body: some View {
        UIKitView(make: UILabel.init)
            .text("\(person.name):\(marker)")
            .configureUIKit { $0.accessibilityIdentifier = "\(prefix)-\(person.id)" }
            .frame(height: 44)
    }
}

@available(iOS 17.0, macCatalyst 17.0, *)
@MainActor
private struct ListBindingHarness: View {
    @ObservedObject var state: ListState

    var body: some View {
        VStack {
            UIKitTableView(state.people, selection: $state.selectedIDs, animatesDifferences: false) {
                PersonRow(person: $0, prefix: "table-row")
            }
            .configureUIKit { $0.accessibilityIdentifier = "table" }
            .frame(height: 280)
            UIKitCollectionView(
                state.people, selection: $state.selectedID,
                layout: {
                    let layout = UICollectionViewFlowLayout()
                    layout.itemSize = CGSize(width: 320, height: 60)
                    return layout
                },
                animatesDifferences: false
            ) {
                PersonRow(person: $0, prefix: "collection-row")
            }
            .configureUIKit { $0.accessibilityIdentifier = "collection" }
            .frame(height: 280)
        }
        .environment(\.rowMarker, state.marker)
    }
}

@MainActor
final class DeclarativeListTests: XCTestCase {
    func testValueChangesPreserveIDsCellsAndSelectionAndRefreshRowEnvironment() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("List bridges require iOS 17.")
        }
        let state = ListState()
        let host = BridgeTestHost(ListBindingHarness(state: state))
        defer { host.close() }
        let mounted = await waitForBridge {
            host.view(UILabel.self, id: "table-row-2")?.text == "Second:inherited"
                && host.view(UILabel.self, id: "collection-row-2")?.text == "Second:inherited"
        }
        XCTAssertTrue(mounted)
        let table = try XCTUnwrap(host.view(UITableView.self, id: "table"))
        let collection = try XCTUnwrap(host.view(UICollectionView.self, id: "collection"))
        let indexPath = IndexPath(item: 1, section: 0)
        let tableCell = try XCTUnwrap(table.cellForRow(at: indexPath))
        let collectionCell = try XCTUnwrap(collection.cellForItem(at: indexPath))
        let tableData = try XCTUnwrap(table.dataSource as? UITableViewDiffableDataSource<Int, Int>)
        let collectionData = try XCTUnwrap(collection.dataSource as? UICollectionViewDiffableDataSource<Int, Int>)

        state.people[1].name = "Renamed"
        state.marker = "changed"
        let updated = await waitForBridge {
            host.view(UILabel.self, id: "table-row-2")?.text == "Renamed:changed"
                && host.view(UILabel.self, id: "collection-row-2")?.text == "Renamed:changed"
                && table.indexPathsForSelectedRows == [indexPath]
                && collection.indexPathsForSelectedItems == [indexPath]
        }
        XCTAssertTrue(updated)
        XCTAssertEqual(tableData.snapshot().itemIdentifiers, [1, 2])
        XCTAssertEqual(collectionData.snapshot().itemIdentifiers, [1, 2])
        XCTAssertTrue(table.cellForRow(at: indexPath) === tableCell)
        XCTAssertTrue(collection.cellForItem(at: indexPath) === collectionCell)
        XCTAssertEqual(state.selectedIDs, [2])
        XCTAssertEqual(state.selectedID, 2)
    }

    func testSelectionMovesBothWaysAndSurvivesFilteringAndReordering() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("List bridges require iOS 17.")
        }
        let state = ListState()
        let host = BridgeTestHost(ListBindingHarness(state: state))
        defer { host.close() }
        let mounted = await waitForBridge {
            host.view(UITableView.self, id: "table")?.indexPathsForSelectedRows?.count == 1
                && host.view(UICollectionView.self, id: "collection")?.indexPathsForSelectedItems?.count == 1
        }
        XCTAssertTrue(mounted)
        let table = try XCTUnwrap(host.view(UITableView.self, id: "table"))
        let collection = try XCTUnwrap(host.view(UICollectionView.self, id: "collection"))
        XCTAssertTrue(table.allowsMultipleSelection)
        XCTAssertFalse(collection.allowsMultipleSelection)

        let first = IndexPath(item: 0, section: 0)
        table.selectRow(at: first, animated: false, scrollPosition: .none)
        table.delegate?.tableView?(table, didSelectRowAt: first)
        XCTAssertEqual(state.selectedIDs, [1, 2])
        collection.selectItem(at: first, animated: false, scrollPosition: [])
        collection.delegate?.collectionView?(collection, didSelectItemAt: first)
        XCTAssertEqual(state.selectedID, 1)

        state.selectedIDs = [2]
        state.selectedID = 2
        state.people.reverse()
        let reordered = await waitForBridge {
            table.indexPathsForSelectedRows == [first]
                && collection.indexPathsForSelectedItems == [first]
        }
        XCTAssertTrue(reordered)

        state.people = [Person(id: 1, name: "Only visible item")]
        let filtered = await waitForBridge {
            table.numberOfRows(inSection: 0) == 1
                && collection.numberOfItems(inSection: 0) == 1
                && (table.indexPathsForSelectedRows ?? []).isEmpty
                && (collection.indexPathsForSelectedItems ?? []).isEmpty
        }
        XCTAssertTrue(filtered)
        XCTAssertEqual(state.selectedIDs, [2])
        XCTAssertEqual(state.selectedID, 2)

        state.people.insert(Person(id: 2, name: "Visible again"), at: 0)
        let restored = await waitForBridge {
            table.indexPathsForSelectedRows == [first]
                && collection.indexPathsForSelectedItems == [first]
        }
        XCTAssertTrue(restored)

        table.deselectRow(at: first, animated: false)
        table.delegate?.tableView?(table, didDeselectRowAt: first)
        XCTAssertTrue(state.selectedIDs.isEmpty)
        state.selectedID = nil
        let cleared = await waitForBridge { (collection.indexPathsForSelectedItems ?? []).isEmpty }
        XCTAssertTrue(cleared)
    }

    func testAllDataInitializersInferTypes() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("List bridges require iOS 17.")
        }
        let people = [Person(id: 1, name: "Name")]
        _ = UIKitTableView(people) { Text($0.name) }
        _ = UIKitTableView(people, selection: .constant(1)) { Text($0.name) }
        _ = UIKitTableView(people, id: \.id, selection: .constant(Set([1]))) { Text($0.name) }
        _ = UIKitTableView(["a"], id: \.self) { Text($0) }
        _ = UIKitCollectionView(people, layout: UICollectionViewFlowLayout.init) { Text($0.name) }
        _ = UIKitCollectionView(
            people, selection: .constant(Set([1])), layout: UICollectionViewFlowLayout.init
        ) { Text($0.name) }
        _ = UIKitCollectionView(
            people, id: \.id, selection: .constant(1), layout: UICollectionViewFlowLayout.init
        ) { Text($0.name) }
        _ = UIKitCollectionView(["a"], id: \.self, layout: UICollectionViewFlowLayout.init) { Text($0) }
    }
}
#endif
