import SwiftUI
import UIKit
import XCTest
@testable import UIKitSwiftUI

private struct PermissiveDecider: UIKitTextFieldDeciding {}

private struct StrictDecider: UIKitTextFieldDeciding {
    func shouldReturn(_ textField: UITextField) -> Bool { false }

    func shouldClear(_ textField: UITextField) -> Bool { false }
}

private final class SubmitRecorder {
    var didSubmit = false
}

@MainActor
final class TextFieldModelTests: XCTestCase {
    func testModelWithoutDeciderAllowsEveryDecision() {
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

    func testDefaultDeciderImplementationsAllowEveryDecision() {
        let model = UIKitTextFieldModel(decider: PermissiveDecider())
        let textField = UITextField()

        XCTAssertTrue(model.shouldBeginEditing(textField))
        XCTAssertTrue(model.shouldEndEditing(textField))
        XCTAssertTrue(model.shouldClear(textField))
        XCTAssertTrue(model.shouldReturn(textField))
    }

    func testCustomDeciderIsConsulted() {
        let model = UIKitTextFieldModel(decider: StrictDecider())
        let textField = UITextField()

        XCTAssertFalse(model.shouldReturn(textField))
        XCTAssertFalse(model.shouldClear(textField))
        XCTAssertTrue(model.shouldBeginEditing(textField))
        XCTAssertTrue(model.shouldEndEditing(textField))
    }

    func testHandleTextChangedUpdatesTextAndEmitsEvent() async {
        let model = UIKitTextFieldModel(text: "Old")
        var iterator = model.events.makeAsyncIterator()

        model.handleTextChanged("New")

        XCTAssertEqual(model.text, "New")
        let event = await iterator.next()
        XCTAssertEqual(event, .textChanged("New"))
    }

    func testHandleClearedEmptiesTextAndEmitsEvent() async {
        let model = UIKitTextFieldModel(text: "Old")
        var iterator = model.events.makeAsyncIterator()

        model.handleCleared()

        XCTAssertEqual(model.text, "")
        let event = await iterator.next()
        XCTAssertEqual(event, .cleared)
    }

    func testHandleSubmittedEmitsEvent() async {
        let model = UIKitTextFieldModel()
        var iterator = model.events.makeAsyncIterator()

        model.handleSubmitted()

        let event = await iterator.next()
        XCTAssertEqual(event, .submitted)
    }

    func testEditingHandlersFlipEditingAndFocus() {
        let model = UIKitTextFieldModel()

        model.handleEditingBegan()

        XCTAssertTrue(model.isEditing)
        XCTAssertTrue(model.isFocused)

        model.handleEditingEnded()

        XCTAssertFalse(model.isEditing)
        XCTAssertFalse(model.isFocused)
    }

    func testEditingHandlersEmitEditingEvents() async {
        let model = UIKitTextFieldModel()
        var iterator = model.events.makeAsyncIterator()

        model.handleEditingBegan()
        model.handleEditingEnded()

        let began = await iterator.next()
        let ended = await iterator.next()
        XCTAssertEqual(began, .editingBegan)
        XCTAssertEqual(ended, .editingEnded)
    }

    func testTextFieldAcceptsObservableModel() {
        let model = UIKitTextFieldModel(text: "Value")

        let textField = UIKitTextField("Placeholder", model: model)

        XCTAssertTrue(type(of: textField) == UIKitTextField.self)
    }

    func testCoordinatorForwardsDelegateCallbacksToModel() {
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

    func testCoordinatorWithoutModelKeepsClosureBehavior() {
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
