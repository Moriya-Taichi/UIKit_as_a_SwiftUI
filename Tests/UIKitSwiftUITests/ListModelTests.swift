import SwiftUI
import UIKit
import XCTest
@testable import UIKitSwiftUI

private typealias StringListModel = UIKitListModel<Int, String>

@MainActor
final class ListModelTests: XCTestCase {
    func testSingleSectionConvenienceBuildsOneSection() {
        let model = StringListModel(items: ["a", "b"])

        XCTAssertEqual(model.items, ["a", "b"])
        XCTAssertEqual(model.sections.count, 1)
        XCTAssertEqual(model.sections.first?.id, 0)
        XCTAssertEqual(model.sections.first?.items, ["a", "b"])
        XCTAssertTrue(model.selectedItems.isEmpty)
    }

    func testItemsSetterReplacesSections() {
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

    func testItemsGetterIsEmptyWithoutSections() {
        let model = StringListModel(sections: [])

        XCTAssertTrue(model.items.isEmpty)
        XCTAssertTrue(model.snapshot().sectionIdentifiers.isEmpty)
    }

    func testSnapshotKeepsSectionAndItemOrder() {
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

    func testHandleSelectedUpdatesSelectionAndEmitsEvent() async {
        let model = StringListModel(items: ["a", "b"])
        var iterator = model.events.makeAsyncIterator()

        model.handleSelected("a")

        XCTAssertEqual(model.selectedItems, ["a"])
        let event = await iterator.next()
        XCTAssertEqual(event, .selected("a"))
    }

    func testHandleSelectedKeepsSelectionUnique() {
        let model = StringListModel(items: ["a", "b"])

        model.handleSelected("a")
        model.handleSelected("b")
        model.handleSelected("a")

        XCTAssertEqual(model.selectedItems, ["a", "b"])
    }

    func testHandleDeselectedRemovesSelectionAndEmitsEvent() async {
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

    func testTableViewBridgesPinGenericTypes() {
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

    func testCollectionViewBridgesPinGenericTypes() {
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

    func testBridgeCoordinatorsForwardSelectionToModel() {
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
}
