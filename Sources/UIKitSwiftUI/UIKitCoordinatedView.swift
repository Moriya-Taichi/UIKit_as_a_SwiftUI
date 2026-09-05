import SwiftUI
import UIKit

/// A `UIViewRepresentable` bridge with a caller-owned coordinator value.
///
/// Use this variant for delegates, data sources, target-action proxies, and
/// other objects that must live for the same duration as the represented view.
@MainActor
public struct UIKitCoordinatedView<ViewType: UIView, CoordinatorValue>: UIViewRepresentable {
    public typealias UIViewType = ViewType

    @MainActor
    public final class Coordinator {
        fileprivate let environment = UIKitEnvironmentState()
        public let value: CoordinatorValue
        fileprivate let dismantle: @MainActor (ViewType, CoordinatorValue) -> Void

        fileprivate init(
            value: CoordinatorValue,
            dismantle: @escaping @MainActor (ViewType, CoordinatorValue) -> Void
        ) {
            self.value = value
            self.dismantle = dismantle
        }
    }

    public typealias MakeUIView = @MainActor (CoordinatorValue, Context) -> ViewType
    public typealias UpdateUIView = @MainActor (
        ViewType,
        CoordinatorValue,
        Context
    ) -> Void
    public typealias DismantleUIView = @MainActor (
        ViewType,
        CoordinatorValue
    ) -> Void
    public typealias MeasureUIView = @MainActor (
        ProposedViewSize,
        ViewType,
        CoordinatorValue,
        Context
    ) -> CGSize?

    private let makeCoordinatorValue: @MainActor () -> CoordinatorValue
    private let make: MakeUIView
    private var update: UpdateUIView
    private let dismantle: DismantleUIView
    private let measure: MeasureUIView?

    public init(
        makeCoordinator: @escaping @MainActor () -> CoordinatorValue,
        make: @escaping MakeUIView,
        update: @escaping UpdateUIView = { _, _, _ in },
        dismantle: @escaping DismantleUIView = { _, _ in },
        sizeThatFits: MeasureUIView? = nil
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

    public func makeUIView(context: Context) -> ViewType {
        let view = make(context.coordinator.value, context)
        context.coordinator.environment.update(view, environment: context.environment) { _ in }
        return view
    }

    public func updateUIView(_ uiView: ViewType, context: Context) {
        context.coordinator.environment.update(uiView, environment: context.environment) {
            update($0, context.coordinator.value, context)
        }
    }

    public static func dismantleUIView(
        _ uiView: ViewType,
        coordinator: Coordinator
    ) {
        coordinator.environment.dismantle()
        coordinator.dismantle(uiView, coordinator.value)
    }

    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: ViewType,
        context: Context
    ) -> CGSize? {
        measure?(proposal, uiView, context.coordinator.value, context)
    }
}


extension UIKitCoordinatedView: UIKitViewConfiguring {
    public typealias UIKitViewType = ViewType

    /// Appends UIKit configuration to each update.
    public func configureUIKit(
        _ body: @escaping @MainActor (ViewType) -> Void
    ) -> Self {
        var copy = self
        let previous = update
        copy.update = { view, coordinator, context in
            previous(view, coordinator, context)
            body(view)
        }
        return copy
    }
}
