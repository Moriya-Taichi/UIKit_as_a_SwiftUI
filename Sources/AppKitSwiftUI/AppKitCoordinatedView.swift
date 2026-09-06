#if os(macOS)
import SwiftUI
import AppKit

/// A `NSViewRepresentable` bridge with a caller-owned coordinator value.
///
/// Use this variant for delegates, data sources, target-action proxies, and
/// other objects that must live for the same duration as the represented view.
@MainActor
public struct AppKitCoordinatedView<ViewType: NSView, CoordinatorValue>: NSViewRepresentable {
    public typealias NSViewType = ViewType

    @MainActor
    public final class Coordinator {
        fileprivate let environment = AppKitEnvironmentState()
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

    public typealias MakeNSView = @MainActor (CoordinatorValue, Context) -> ViewType
    public typealias UpdateNSView = @MainActor (
        ViewType,
        CoordinatorValue,
        Context
    ) -> Void
    public typealias DismantleNSView = @MainActor (
        ViewType,
        CoordinatorValue
    ) -> Void
    public typealias MeasureNSView = @MainActor (
        ProposedViewSize,
        ViewType,
        CoordinatorValue,
        Context
    ) -> CGSize?

    private let makeCoordinatorValue: @MainActor () -> CoordinatorValue
    private let make: MakeNSView
    private var update: UpdateNSView
    private let dismantle: DismantleNSView
    private let measure: MeasureNSView?

    public init(
        makeCoordinator: @escaping @MainActor () -> CoordinatorValue,
        make: @escaping MakeNSView,
        update: @escaping UpdateNSView = { _, _, _ in },
        dismantle: @escaping DismantleNSView = { _, _ in },
        sizeThatFits: MeasureNSView? = nil
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

    public func makeNSView(context: Context) -> ViewType {
        let view = make(context.coordinator.value, context)
        context.coordinator.environment.update(view, environment: context.environment) { _ in }
        return view
    }

    public func updateNSView(_ nsView: ViewType, context: Context) {
        context.coordinator.environment.update(nsView, environment: context.environment) {
            update($0, context.coordinator.value, context)
        }
    }

    public static func dismantleNSView(
        _ nsView: ViewType,
        coordinator: Coordinator
    ) {
        coordinator.environment.dismantle()
        coordinator.dismantle(nsView, coordinator.value)
    }

    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: ViewType,
        context: Context
    ) -> CGSize? {
        measure?(proposal, nsView, context.coordinator.value, context)
    }
}


extension AppKitCoordinatedView: AppKitViewConfiguring {
    public typealias AppKitViewType = ViewType

    /// Appends AppKit configuration to each update.
    public func configureAppKit(
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
#endif
