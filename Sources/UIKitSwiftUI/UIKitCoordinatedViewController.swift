#if canImport(UIKit)
import SwiftUI
import UIKit

/// A `UIViewControllerRepresentable` bridge with a caller-owned coordinator.
@MainActor
public struct UIKitCoordinatedViewController<
    ControllerType: UIViewController,
    CoordinatorValue
>: UIViewControllerRepresentable {
    public typealias UIViewControllerType = ControllerType

    public final class Coordinator {
        public let value: CoordinatorValue
        fileprivate let dismantle: @MainActor (
            ControllerType,
            CoordinatorValue
        ) -> Void

        fileprivate init(
            value: CoordinatorValue,
            dismantle: @escaping @MainActor (
                ControllerType,
                CoordinatorValue
            ) -> Void
        ) {
            self.value = value
            self.dismantle = dismantle
        }
    }

    public typealias MakeController = @MainActor (
        CoordinatorValue,
        Context
    ) -> ControllerType
    public typealias UpdateController = @MainActor (
        ControllerType,
        CoordinatorValue,
        Context
    ) -> Void
    public typealias DismantleController = @MainActor (
        ControllerType,
        CoordinatorValue
    ) -> Void
    public typealias MeasureController = @MainActor (
        ProposedViewSize,
        ControllerType,
        CoordinatorValue,
        Context
    ) -> CGSize?

    private let makeCoordinatorValue: @MainActor () -> CoordinatorValue
    private let make: MakeController
    private var update: UpdateController
    private let dismantle: DismantleController
    private let measure: MeasureController?

    public init(
        makeCoordinator: @escaping @MainActor () -> CoordinatorValue,
        make: @escaping MakeController,
        update: @escaping UpdateController = { _, _, _ in },
        dismantle: @escaping DismantleController = { _, _ in },
        sizeThatFits: MeasureController? = nil
    ) {
        makeCoordinatorValue = makeCoordinator
        self.make = make
        self.update = update
        self.dismantle = dismantle
        measure = sizeThatFits
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(value: makeCoordinatorValue(), dismantle: dismantle)
    }

    public func makeUIViewController(context: Context) -> ControllerType {
        make(context.coordinator.value, context)
    }

    public func updateUIViewController(
        _ uiViewController: ControllerType,
        context: Context
    ) {
        update(
            uiViewController,
            context.coordinator.value,
            context
        )
    }

    public static func dismantleUIViewController(
        _ uiViewController: ControllerType,
        coordinator: Coordinator
    ) {
        coordinator.dismantle(uiViewController, coordinator.value)
    }

    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiViewController: ControllerType,
        context: Context
    ) -> CGSize? {
        measure?(
            proposal,
            uiViewController,
            context.coordinator.value,
            context
        )
    }
}


public extension UIKitCoordinatedViewController {
    /// Appends UIKit controller configuration to each update.
    func configureUIKit(
        _ body: @escaping @MainActor (ControllerType) -> Void
    ) -> Self {
        var copy = self
        let previous = update
        copy.update = { controller, coordinator, context in
            previous(controller, coordinator, context)
            body(controller)
        }
        return copy
    }
}
#endif
