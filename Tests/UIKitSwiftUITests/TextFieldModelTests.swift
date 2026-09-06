#if canImport(UIKit)
import SwiftUI
import UIKit
import XCTest
@testable import UIKitSwiftUI

@available(iOS 17.0, macCatalyst 17.0, *)
private struct PermissiveDecider: UIKitTextFieldDeciding {}

@available(iOS 17.0, macCatalyst 17.0, *)
private struct StrictDecider: UIKitTextFieldDeciding {
    func shouldReturn(_ textField: UITextField) -> Bool { false }

    func shouldClear(_ textField: UITextField) -> Bool { false }
}

private final class SubmitRecorder {
    var didSubmit = false
}

@MainActor
final class TextFieldModelTests: XCTestCase {
    func testModelWithoutDeciderAllowsEveryDecision() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextFieldModel()
        let textField = UITextField()

        XCTAssertTrue(model.shouldBeginEditing(textField))
        XCTAssertTrue(model.shouldEndEditing(textField))
        XCTAssertTrue(
            model.shouldChangeText(
                in: NSRange(location: 0, length: 0),
                replacement: "a",
                textField: textField
            )
        )
        XCTAssertTrue(model.shouldClear(textField))
        XCTAssertTrue(model.shouldReturn(textField))
    }

    func testDefaultDeciderImplementationsAllowEveryDecision() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextFieldModel(decider: PermissiveDecider())
        let textField = UITextField()

        XCTAssertTrue(model.shouldBeginEditing(textField))
        XCTAssertTrue(model.shouldEndEditing(textField))
        XCTAssertTrue(model.shouldClear(textField))
        XCTAssertTrue(model.shouldReturn(textField))
    }

    func testCustomDeciderIsConsulted() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextFieldModel(decider: StrictDecider())
        let textField = UITextField()

        XCTAssertFalse(model.shouldReturn(textField))
        XCTAssertFalse(model.shouldClear(textField))
        XCTAssertTrue(model.shouldBeginEditing(textField))
        XCTAssertTrue(model.shouldEndEditing(textField))
    }

    func testHandleTextChangedUpdatesTextAndEmitsEvent() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextFieldModel(text: "Old")
        var iterator = model.events.makeAsyncIterator()

        model.handleTextChanged("New")

        XCTAssertEqual(model.text, "New")
        let event = await iterator.next()
        XCTAssertEqual(event, .textChanged("New"))
    }

    func testHandleClearedEmptiesTextAndEmitsEvent() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextFieldModel(text: "Old")
        var iterator = model.events.makeAsyncIterator()

        model.handleCleared()

        XCTAssertEqual(model.text, "")
        let event = await iterator.next()
        XCTAssertEqual(event, .cleared)
    }

    func testHandleSubmittedEmitsEvent() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextFieldModel()
        var iterator = model.events.makeAsyncIterator()

        model.handleSubmitted()

        let event = await iterator.next()
        XCTAssertEqual(event, .submitted)
    }

    func testEditingHandlersFlipEditingAndFocus() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextFieldModel()

        model.handleEditingBegan()

        XCTAssertTrue(model.isEditing)
        XCTAssertTrue(model.isFocused)

        model.handleEditingEnded()

        XCTAssertFalse(model.isEditing)
        XCTAssertFalse(model.isFocused)
    }

    func testEditingHandlersEmitEditingEvents() async throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextFieldModel()
        var iterator = model.events.makeAsyncIterator()

        model.handleEditingBegan()
        model.handleEditingEnded()

        let began = await iterator.next()
        let ended = await iterator.next()
        XCTAssertEqual(began, .editingBegan)
        XCTAssertEqual(ended, .editingEnded)
    }

    func testTextFieldAcceptsObservableModel() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextFieldModel(text: "Value")

        let textField = UIKitTextField("Placeholder", model: model)

        XCTAssertTrue(type(of: textField) == UIKitTextField.self)
    }

    func testCoordinatorForwardsDelegateCallbacksToModel() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let model = UIKitTextFieldModel(decider: StrictDecider())
        let bridge = UIKitTextField(model: model)
        let coordinator = bridge.makeCoordinator()
        let textField = UITextField()

        coordinator.textFieldDidBeginEditing(textField)

        XCTAssertTrue(model.isEditing)
        XCTAssertTrue(model.isFocused)
        XCTAssertTrue(coordinator.textFieldShouldBeginEditing(textField))
        XCTAssertFalse(coordinator.textFieldShouldReturn(textField))
        XCTAssertFalse(coordinator.textFieldShouldClear(textField))

        coordinator.textFieldDidEndEditing(textField)

        XCTAssertFalse(model.isEditing)
        XCTAssertFalse(model.isFocused)
    }

    func testCoordinatorWithoutModelKeepsClosureBehavior() throws {
        guard #available(iOS 17.0, macCatalyst 17.0, *) else {
            throw XCTSkip("Observable models require iOS 17.")
        }

        let recorder = SubmitRecorder()
        let bridge = UIKitTextField(
            text: .constant("Value"),
            onSubmit: { recorder.didSubmit = true },
            shouldChange: { _, _ in false }
        )
        let coordinator = bridge.makeCoordinator()
        let textField = UITextField()

        XCTAssertTrue(coordinator.textFieldShouldBeginEditing(textField))
        XCTAssertTrue(coordinator.textFieldShouldEndEditing(textField))
        XCTAssertTrue(coordinator.textFieldShouldClear(textField))
        XCTAssertTrue(coordinator.textFieldShouldReturn(textField))
        XCTAssertTrue(recorder.didSubmit)
        XCTAssertFalse(
            coordinator.textField(
                textField,
                shouldChangeCharactersIn: NSRange(location: 0, length: 0),
                replacementString: "a"
            )
        )
    }
}
#endif
