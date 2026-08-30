import SwiftUI
import UIKit
import XCTest
@testable import UIKitSwiftUI

@available(iOS 17.0, macCatalyst 17.0, *)
private struct PermissiveTextViewDecider: UIKitTextViewDeciding {}

@available(iOS 17.0, macCatalyst 17.0, *)
private struct StrictTextViewDecider: UIKitTextViewDeciding {
    func shouldEndEditing(_ textView: UITextView) -> Bool { false }

    func shouldChangeText(
        in range: NSRange,
        replacement: String,
        textView: UITextView
    ) -> Bool { false }
}

@available(iOS 17.0, macCatalyst 17.0, *)
private struct PermissiveSearchBarDecider: UIKitSearchBarDeciding {}

@available(iOS 17.0, macCatalyst 17.0, *)
private struct StrictSearchBarDecider: UIKitSearchBarDeciding {
    func shouldBeginEditing(_ searchBar: UISearchBar) -> Bool { false }

    func shouldChangeText(
        in range: NSRange,
        replacement: String,
        searchBar: UISearchBar
    ) -> Bool { false }
}

private final class CallbackRecorder {
    var editingChanges: [Bool] = []
    var didSubmit = false
    var didCancel = false
}

@MainActor
final class TextInputModelTests: XCTestCase {
    // MARK: - Text view model

    func testTextViewModelWithoutDeciderAllowsEveryDecision() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextViewModel()
        let textView = UITextView()

        XCTAssertTrue(model.shouldBeginEditing(textView))
        XCTAssertTrue(model.shouldEndEditing(textView))
        XCTAssertTrue(
            model.shouldChangeText(
                in: NSRange(location: 0, length: 0),
                replacement: "a",
                textView: textView
            )
        )
    }

    func testTextViewDefaultDeciderImplementationsAllowEveryDecision() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextViewModel(decider: PermissiveTextViewDecider())
        let textView = UITextView()

        XCTAssertTrue(model.shouldBeginEditing(textView))
        XCTAssertTrue(model.shouldEndEditing(textView))
        XCTAssertTrue(
            model.shouldChangeText(
                in: NSRange(location: 0, length: 0),
                replacement: "a",
                textView: textView
            )
        )
    }

    func testTextViewCustomDeciderIsConsulted() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextViewModel(decider: StrictTextViewDecider())
        let textView = UITextView()

        XCTAssertTrue(model.shouldBeginEditing(textView))
        XCTAssertFalse(model.shouldEndEditing(textView))
        XCTAssertFalse(
            model.shouldChangeText(
                in: NSRange(location: 0, length: 0),
                replacement: "a",
                textView: textView
            )
        )
    }

    func testTextViewHandleTextChangedUpdatesTextAndEmitsEvent() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextViewModel(text: "Old")
        var iterator = model.events.makeAsyncIterator()

        model.handleTextChanged("New")

        XCTAssertEqual(model.text, "New")
        let event = await iterator.next()
        XCTAssertEqual(event, .textChanged("New"))
    }

    func testTextViewHandleSelectionChangedEmitsEvent() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextViewModel(text: "Value")
        var iterator = model.events.makeAsyncIterator()
        let range = NSRange(location: 1, length: 3)

        model.handleSelectionChanged(range)

        let event = await iterator.next()
        XCTAssertEqual(event, .selectionChanged(range))
    }

    func testTextViewEditingHandlersFlipEditingAndFocus() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextViewModel()

        model.handleEditingBegan()

        XCTAssertTrue(model.isEditing)
        XCTAssertTrue(model.isFocused)

        model.handleEditingEnded()

        XCTAssertFalse(model.isEditing)
        XCTAssertFalse(model.isFocused)
    }

    func testTextViewEditingHandlersEmitEditingEvents() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextViewModel()
        var iterator = model.events.makeAsyncIterator()

        model.handleEditingBegan()
        model.handleEditingEnded()

        let began = await iterator.next()
        let ended = await iterator.next()
        XCTAssertEqual(began, .editingBegan)
        XCTAssertEqual(ended, .editingEnded)
    }

    func testTextViewAcceptsObservableModel() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextViewModel(text: "Value")

        let textView = UIKitTextView(model: model)

        XCTAssertTrue(type(of: textView) == UIKitTextView.self)
    }

    func testTextViewCoordinatorForwardsDelegateCallbacksToModel() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextViewModel(decider: StrictTextViewDecider())
        let bridge = UIKitTextView(model: model)
        let coordinator = bridge.makeCoordinator()
        let textView = UITextView()
        var iterator = model.events.makeAsyncIterator()

        coordinator.textViewDidBeginEditing(textView)

        XCTAssertTrue(model.isEditing)
        XCTAssertTrue(model.isFocused)
        XCTAssertTrue(coordinator.textViewShouldBeginEditing(textView))
        XCTAssertFalse(coordinator.textViewShouldEndEditing(textView))
        XCTAssertFalse(
            coordinator.textView(
                textView,
                shouldChangeTextIn: NSRange(location: 0, length: 0),
                replacementText: "a"
            )
        )

        textView.text = "Typed"
        coordinator.textViewDidChange(textView)

        XCTAssertEqual(model.text, "Typed")

        coordinator.textViewDidChangeSelection(textView)
        coordinator.textViewDidEndEditing(textView)

        XCTAssertFalse(model.isEditing)
        XCTAssertFalse(model.isFocused)

        let began = await iterator.next()
        let changed = await iterator.next()
        let selection = await iterator.next()
        let ended = await iterator.next()
        XCTAssertEqual(began, .editingBegan)
        XCTAssertEqual(changed, .textChanged("Typed"))
        XCTAssertEqual(selection, .selectionChanged(textView.selectedRange))
        XCTAssertEqual(ended, .editingEnded)
    }

    func testTextViewCoordinatorWithoutModelKeepsClosureBehavior() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let recorder = CallbackRecorder()
        let bridge = UIKitTextView(
            text: .constant("Value"),
            onEditingChanged: { recorder.editingChanges.append($0) }
        )
        let coordinator = bridge.makeCoordinator()
        let textView = UITextView()

        XCTAssertTrue(coordinator.textViewShouldBeginEditing(textView))
        XCTAssertTrue(coordinator.textViewShouldEndEditing(textView))
        XCTAssertTrue(
            coordinator.textView(
                textView,
                shouldChangeTextIn: NSRange(location: 0, length: 0),
                replacementText: "a"
            )
        )

        coordinator.textViewDidBeginEditing(textView)
        coordinator.textViewDidEndEditing(textView)

        XCTAssertEqual(recorder.editingChanges, [true, false])
    }

    // MARK: - Search bar model

    func testSearchBarModelWithoutDeciderAllowsEveryDecision() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitSearchBarModel()
        let searchBar = UISearchBar()

        XCTAssertTrue(model.shouldBeginEditing(searchBar))
        XCTAssertTrue(model.shouldEndEditing(searchBar))
        XCTAssertTrue(
            model.shouldChangeText(
                in: NSRange(location: 0, length: 0),
                replacement: "a",
                searchBar: searchBar
            )
        )
    }

    func testSearchBarDefaultDeciderImplementationsAllowEveryDecision() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitSearchBarModel(decider: PermissiveSearchBarDecider())
        let searchBar = UISearchBar()

        XCTAssertTrue(model.shouldBeginEditing(searchBar))
        XCTAssertTrue(model.shouldEndEditing(searchBar))
        XCTAssertTrue(
            model.shouldChangeText(
                in: NSRange(location: 0, length: 0),
                replacement: "a",
                searchBar: searchBar
            )
        )
    }

    func testSearchBarCustomDeciderIsConsulted() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitSearchBarModel(decider: StrictSearchBarDecider())
        let searchBar = UISearchBar()

        XCTAssertFalse(model.shouldBeginEditing(searchBar))
        XCTAssertTrue(model.shouldEndEditing(searchBar))
        XCTAssertFalse(
            model.shouldChangeText(
                in: NSRange(location: 0, length: 0),
                replacement: "a",
                searchBar: searchBar
            )
        )
    }

    func testSearchBarHandleTextChangedUpdatesTextAndEmitsEvent() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitSearchBarModel(text: "Old")
        var iterator = model.events.makeAsyncIterator()

        model.handleTextChanged("New")

        XCTAssertEqual(model.text, "New")
        let event = await iterator.next()
        XCTAssertEqual(event, .textChanged("New"))
    }

    func testSearchBarHandleSubmittedEmitsEvent() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitSearchBarModel(text: "Query")
        var iterator = model.events.makeAsyncIterator()

        model.handleSubmitted()

        let event = await iterator.next()
        XCTAssertEqual(event, .submitted)
    }

    func testSearchBarHandleCancelledKeepsTextAndEmitsEvent() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitSearchBarModel(text: "Query")
        var iterator = model.events.makeAsyncIterator()

        model.handleCancelled()

        XCTAssertEqual(model.text, "Query")
        let event = await iterator.next()
        XCTAssertEqual(event, .cancelled)
    }

    func testSearchBarEditingHandlersFlipEditingAndFocus() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitSearchBarModel()

        model.handleEditingBegan()

        XCTAssertTrue(model.isEditing)
        XCTAssertTrue(model.isFocused)

        model.handleEditingEnded()

        XCTAssertFalse(model.isEditing)
        XCTAssertFalse(model.isFocused)
    }

    func testSearchBarAcceptsObservableModel() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitSearchBarModel(text: "Query")

        let searchBar = UIKitSearchBar(model: model, prompt: "Search")

        XCTAssertTrue(type(of: searchBar) == UIKitSearchBar.self)
    }

    func testSearchBarCoordinatorForwardsDelegateCallbacksToModel() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitSearchBarModel(decider: StrictSearchBarDecider())
        let bridge = UIKitSearchBar(model: model)
        let coordinator = bridge.makeCoordinator()
        let searchBar = UISearchBar()
        var iterator = model.events.makeAsyncIterator()

        coordinator.searchBarTextDidBeginEditing(searchBar)

        XCTAssertTrue(model.isEditing)
        XCTAssertTrue(model.isFocused)
        XCTAssertFalse(coordinator.searchBarShouldBeginEditing(searchBar))
        XCTAssertTrue(coordinator.searchBarShouldEndEditing(searchBar))
        XCTAssertFalse(
            coordinator.searchBar(
                searchBar,
                shouldChangeTextIn: NSRange(location: 0, length: 0),
                replacementText: "a"
            )
        )

        coordinator.searchBar(searchBar, textDidChange: "Typed")
        coordinator.searchBarSearchButtonClicked(searchBar)
        coordinator.searchBarCancelButtonClicked(searchBar)

        XCTAssertEqual(model.text, "Typed")

        coordinator.searchBarTextDidEndEditing(searchBar)

        XCTAssertFalse(model.isEditing)
        XCTAssertFalse(model.isFocused)

        let began = await iterator.next()
        let changed = await iterator.next()
        let submitted = await iterator.next()
        let cancelled = await iterator.next()
        let ended = await iterator.next()
        XCTAssertEqual(began, .editingBegan)
        XCTAssertEqual(changed, .textChanged("Typed"))
        XCTAssertEqual(submitted, .submitted)
        XCTAssertEqual(cancelled, .cancelled)
        XCTAssertEqual(ended, .editingEnded)
    }

    func testSearchBarCoordinatorWithoutModelKeepsClosureBehavior() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let recorder = CallbackRecorder()
        let bridge = UIKitSearchBar(
            text: .constant("Value"),
            onSubmit: { recorder.didSubmit = true },
            onCancel: { recorder.didCancel = true }
        )
        let coordinator = bridge.makeCoordinator()
        let searchBar = UISearchBar()

        XCTAssertTrue(coordinator.searchBarShouldBeginEditing(searchBar))
        XCTAssertTrue(coordinator.searchBarShouldEndEditing(searchBar))
        XCTAssertTrue(
            coordinator.searchBar(
                searchBar,
                shouldChangeTextIn: NSRange(location: 0, length: 0),
                replacementText: "a"
            )
        )

        coordinator.searchBarSearchButtonClicked(searchBar)
        coordinator.searchBarCancelButtonClicked(searchBar)

        XCTAssertTrue(recorder.didSubmit)
        XCTAssertTrue(recorder.didCancel)
    }
}
