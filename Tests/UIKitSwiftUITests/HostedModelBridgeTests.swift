#if canImport(UIKit)
import SwiftUI
import UIKit
import XCTest
@testable import UIKitSwiftUI

@available(iOS 17.0, macCatalyst 17.0, *)
@MainActor
private struct TextInputHarness: View {
    let textFieldModel: UIKitTextFieldModel
    let textViewModel: UIKitTextViewModel
    let searchBarModel: UIKitSearchBarModel

    var body: some View {
        VStack {
            UIKitTextField(model: textFieldModel) {
                $0.accessibilityIdentifier = "model-text-field"
            }
            UIKitTextView(model: textViewModel) {
                $0.accessibilityIdentifier = "model-text-view"
            }
            UIKitSearchBar(model: searchBarModel) {
                $0.accessibilityIdentifier = "model-search-bar"
            }
        }
    }
}

@available(iOS 17.0, macCatalyst 17.0, *)
@MainActor
private struct ListHarness: View {
    let model: UIKitListModel<Int, String>

    var body: some View {
        VStack {
            UIKitTableView(
                model: model,
                configure: {
                    $0.accessibilityIdentifier = "model-table-view"
                },
                content: { item in
                    var configuration = UIListContentConfiguration.cell()
                    configuration.text = item
                    return configuration
                }
            )
            UIKitCollectionView(
                model: model,
                layout: { UICollectionViewFlowLayout() },
                configure: {
                    $0.accessibilityIdentifier = "model-collection-view"
                },
                content: { item in
                    var configuration = UIListContentConfiguration.cell()
                    configuration.text = item
                    return configuration
                }
            )
        }
    }
}

@MainActor
final class HostedModelBridgeTests: XCTestCase {
    func testHostedTextInputsTrackProgrammaticModelChanges() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let textFieldModel = UIKitTextFieldModel(text: "Before field")
        let textViewModel = UIKitTextViewModel(text: "Before view")
        let searchBarModel = UIKitSearchBarModel(text: "Before search")
        let controller = UIHostingController(
            rootView: TextInputHarness(
                textFieldModel: textFieldModel,
                textViewModel: textViewModel,
                searchBarModel: searchBarModel
            )
        )
        let window = host(controller)
        defer { window.isHidden = true }

        let didMount = await eventually {
            self.textField(in: controller.view) != nil
                && self.textView(in: controller.view) != nil
                && self.searchBar(in: controller.view) != nil
        }
        XCTAssertTrue(didMount)

        textFieldModel.text = "After field"
        textViewModel.text = "After view"
        searchBarModel.text = "After search"

        let didUpdate = await eventually {
            self.textField(in: controller.view)?.text == "After field"
                && self.textView(in: controller.view)?.text == "After view"
                && self.searchBar(in: controller.view)?.text == "After search"
        }
        XCTAssertTrue(didUpdate)
    }

    func testHostedListsTrackProgrammaticModelChanges() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitListModel<Int, String>(items: ["a"])
        let controller = UIHostingController(rootView: ListHarness(model: model))
        let window = host(controller)
        defer { window.isHidden = true }

        let didMount = await eventually {
            self.tableView(in: controller.view)?.numberOfRows(inSection: 0) == 1
                && self.collectionView(in: controller.view)?
                    .numberOfItems(inSection: 0) == 1
        }
        XCTAssertTrue(didMount)

        model.items = ["a", "b"]

        let didUpdate = await eventually {
            self.tableView(in: controller.view)?.numberOfRows(inSection: 0) == 2
                && self.collectionView(in: controller.view)?
                    .numberOfItems(inSection: 0) == 2
        }
        XCTAssertTrue(didUpdate)
    }

    private func host<Content: View>(
        _ controller: UIHostingController<Content>
    ) -> UIWindow {
        let window = UIWindow(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844)
        )
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        return window
    }

    private func eventually(
        _ condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        for _ in 0..<100 {
            if condition() {
                return true
            }
            try? await Task<Never, Never>.sleep(nanoseconds: 10_000_000)
        }
        return condition()
    }

    private func textField(in root: UIView) -> UITextField? {
        descendant(in: root) {
            ($0 as? UITextField)?.accessibilityIdentifier
                == "model-text-field"
        }
    }

    private func textView(in root: UIView) -> UITextView? {
        descendant(in: root) {
            ($0 as? UITextView)?.accessibilityIdentifier == "model-text-view"
        }
    }

    private func searchBar(in root: UIView) -> UISearchBar? {
        descendant(in: root) {
            ($0 as? UISearchBar)?.accessibilityIdentifier
                == "model-search-bar"
        }
    }

    private func tableView(in root: UIView) -> UITableView? {
        descendant(in: root) {
            ($0 as? UITableView)?.accessibilityIdentifier
                == "model-table-view"
        }
    }

    private func collectionView(in root: UIView) -> UICollectionView? {
        descendant(in: root) {
            ($0 as? UICollectionView)?.accessibilityIdentifier
                == "model-collection-view"
        }
    }

    private func descendant<View: UIView>(
        in root: UIView,
        matching predicate: (UIView) -> Bool
    ) -> View? {
        if predicate(root), let match = root as? View {
            return match
        }
        for subview in root.subviews {
            if let match: View = descendant(in: subview, matching: predicate) {
                return match
            }
        }
        return nil
    }
}
#endif
