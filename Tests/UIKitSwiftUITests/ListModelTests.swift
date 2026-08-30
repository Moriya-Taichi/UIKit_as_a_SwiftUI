import SwiftUI
import UIKit
import XCTest
@testable import UIKitSwiftUI

@available(iOS 17.0, macCatalyst 17.0, *)
private typealias StringListModel = UIKitListModel<Int, String>

@MainActor
final class ListModelTests: XCTestCase {
    func testSingleSectionConvenienceBuildsOneSection() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = StringListModel(items: ["a", "b"])

        XCTAssertEqual(model.items, ["a", "b"])
        XCTAssertEqual(model.sections.count, 1)
        XCTAssertEqual(model.sections.first?.id, 0)
        XCTAssertEqual(model.sections.first?.items, ["a", "b"])
        XCTAssertTrue(model.selectedItems.isEmpty)
    }

    func testItemsSetterReplacesSections() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = StringListModel(
            sections: [
                StringListModel.Section(id: 3, items: ["a"]),
                StringListModel.Section(id: 4, items: ["b"]),
            ]
        )

        model.items = ["c", "d"]

        XCTAssertEqual(
            model.sections,
            [StringListModel.Section(id: 0, items: ["c", "d"])]
        )
        XCTAssertEqual(model.items, ["c", "d"])
    }

    func testItemsGetterIsEmptyWithoutSections() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = StringListModel(sections: [])

        XCTAssertTrue(model.items.isEmpty)
        XCTAssertTrue(model.snapshot().sectionIdentifiers.isEmpty)
    }

    func testSnapshotKeepsSectionAndItemOrder() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = StringListModel(
            sections: [
                StringListModel.Section(id: 0, items: ["a", "b"]),
                StringListModel.Section(id: 1, items: ["c"]),
            ]
        )

        let snapshot = model.snapshot()

        XCTAssertEqual(snapshot.sectionIdentifiers, [0, 1])
        XCTAssertEqual(snapshot.itemIdentifiers, ["a", "b", "c"])
        XCTAssertEqual(snapshot.itemIdentifiers(inSection: 0), ["a", "b"])
        XCTAssertEqual(snapshot.itemIdentifiers(inSection: 1), ["c"])
    }

    func testHandleSelectedUpdatesSelectionAndEmitsEvent() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = StringListModel(items: ["a", "b"])
        var iterator = model.events.makeAsyncIterator()

        model.handleSelected("a")

        XCTAssertEqual(model.selectedItems, ["a"])
        let event = await iterator.next()
        XCTAssertEqual(event, .selected("a"))
    }

    func testHandleSelectedKeepsSelectionUnique() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = StringListModel(items: ["a", "b"])

        model.handleSelected("a")
        model.handleSelected("b")
        model.handleSelected("a")

        XCTAssertEqual(model.selectedItems, ["a", "b"])
    }

    func testHandleDeselectedRemovesSelectionAndEmitsEvent() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = StringListModel(items: ["a", "b"])
        var iterator = model.events.makeAsyncIterator()

        model.handleSelected("a")
        model.handleDeselected("a")

        XCTAssertTrue(model.selectedItems.isEmpty)
        let selected = await iterator.next()
        let deselected = await iterator.next()
        XCTAssertEqual(selected, .selected("a"))
        XCTAssertEqual(deselected, .deselected("a"))
    }

    func testRemovingItemsPrunesSelection() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = StringListModel(items: ["a", "b", "c"])
        model.handleSelected("a")
        model.handleSelected("b")

        model.items = ["b", "c"]

        XCTAssertEqual(model.selectedItems, ["b"])
    }

    func testTableViewBridgesPinGenericTypes() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = StringListModel(items: ["a"])
        let provided = UIKitTableView(
            model: model,
            cell: { tableView, indexPath, _ in
                tableView.dequeueReusableCell(
                    withIdentifier: "Cell",
                    for: indexPath
                )
            }
        )
        let listContent = UIKitTableView(
            model: model,
            style: .insetGrouped,
            content: { item in
                var configuration = UIListContentConfiguration.cell()
                configuration.text = item
                return configuration
            }
        )

        XCTAssertTrue(type(of: provided) == UIKitTableView<Int, String>.self)
        XCTAssertTrue(
            type(of: listContent) == UIKitTableView<Int, String>.self
        )
    }

    func testCollectionViewBridgesPinGenericTypes() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = StringListModel(items: ["a"])
        let typed = UIKitCollectionView(
            model: model,
            layout: { UICollectionViewFlowLayout() },
            cellType: UICollectionViewCell.self,
            cell: { _, _, _ in }
        )
        let listContent = UIKitCollectionView(
            model: model,
            layout: { UICollectionViewFlowLayout() },
            content: { item in
                var configuration = UIListContentConfiguration.cell()
                configuration.text = item
                return configuration
            }
        )

        XCTAssertTrue(
            type(of: typed) == UIKitCollectionView<Int, String>.self
        )
        XCTAssertTrue(
            type(of: listContent) == UIKitCollectionView<Int, String>.self
        )
    }

    func testBridgeCoordinatorsForwardSelectionToModel() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = StringListModel(items: ["a"])
        let table = UIKitTableView(
            model: model,
            cell: { tableView, indexPath, _ in
                tableView.dequeueReusableCell(
                    withIdentifier: "Cell",
                    for: indexPath
                )
            }
        )
        let collection = UIKitCollectionView(
            model: model,
            layout: { UICollectionViewFlowLayout() },
            cellType: UICollectionViewCell.self,
            cell: { _, _, _ in }
        )

        let tableCoordinator = table.makeCoordinator()
        let collectionCoordinator = collection.makeCoordinator()

        // Without a data source no item resolves, so the model is untouched.
        tableCoordinator.tableView(
            UITableView(),
            didSelectRowAt: IndexPath(row: 0, section: 0)
        )
        collectionCoordinator.collectionView(
            UICollectionView(
                frame: .zero,
                collectionViewLayout: UICollectionViewFlowLayout()
            ),
            didSelectItemAt: IndexPath(item: 0, section: 0)
        )

        XCTAssertTrue(model.selectedItems.isEmpty)
    }

    func testUpdateSnapshotReconfiguresPersistingItems() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        var current = NSDiffableDataSourceSnapshot<Int, String>()
        current.appendSections([0])
        current.appendItems(["a", "b", "c"], toSection: 0)
        var updated = NSDiffableDataSourceSnapshot<Int, String>()
        updated.appendSections([0])
        updated.appendItems(["b", "c", "d"], toSection: 0)

        let result = UIKitTableView<Int, String>.updateSnapshot(
            current: current,
            updated: updated
        )

        XCTAssertEqual(result.reconfiguredItemIdentifiers, ["b", "c"])
        XCTAssertEqual(result.itemIdentifiers, ["b", "c", "d"])
    }

    func testUpdateSnapshotReconfiguresEveryItemOfAnUnchangedSnapshot() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        var current = NSDiffableDataSourceSnapshot<Int, String>()
        current.appendSections([0])
        current.appendItems(["a", "b"], toSection: 0)
        var updated = NSDiffableDataSourceSnapshot<Int, String>()
        updated.appendSections([0])
        updated.appendItems(["a", "b"], toSection: 0)

        let result = UIKitTableView<Int, String>.updateSnapshot(
            current: current,
            updated: updated
        )

        XCTAssertEqual(result.reconfiguredItemIdentifiers, ["a", "b"])
        XCTAssertEqual(result.itemIdentifiers, ["a", "b"])
    }

    func testUpdateSnapshotReconfiguresNothingWhenNoItemPersists() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        var current = NSDiffableDataSourceSnapshot<Int, String>()
        current.appendSections([0])
        current.appendItems(["a", "b"], toSection: 0)
        var updated = NSDiffableDataSourceSnapshot<Int, String>()
        updated.appendSections([0])
        updated.appendItems(["c", "d"], toSection: 0)

        let result = UIKitTableView<Int, String>.updateSnapshot(
            current: current,
            updated: updated
        )

        XCTAssertTrue(result.reconfiguredItemIdentifiers.isEmpty)
        XCTAssertEqual(result.itemIdentifiers, ["c", "d"])
    }

    // The models buffer the newest 64 unconsumed events, so a 65th yield
    // drops the oldest one and the first element received is the second.
    func testEventStreamKeepsOnlyTheNewestBufferedEvents() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextFieldModel()
        var iterator = model.events.makeAsyncIterator()

        for value in 0...64 {
            model.handleTextChanged("\(value)")
        }

        let event = await iterator.next()
        XCTAssertEqual(event, .textChanged("1"))
    }
}
