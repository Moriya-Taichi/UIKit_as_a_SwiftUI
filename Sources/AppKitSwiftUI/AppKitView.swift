#if os(macOS)
import SwiftUI
import AppKit

/// A lifecycle-aware SwiftUI representation of any `NSView` subclass.
///
/// `AppKitView` is the universal entry point of this package. Because the view
/// type is generic, it also supports AppKit view classes introduced by a newer
/// SDK without requiring a package release.
@MainActor
public struct AppKitView<ViewType: NSView>: NSViewRepresentable {
    public typealias NSViewType = ViewType
    public typealias MakeNSView = @MainActor (Context) -> ViewType
    public typealias UpdateNSView = @MainActor (ViewType, Context) -> Void
    public typealias DismantleNSView = @MainActor (ViewType) -> Void
    public typealias MeasureNSView = @MainActor (
        ProposedViewSize,
        ViewType,
        Context
    ) -> CGSize?

    /// The coordinator is public so `AppKitView` remains usable across module
    /// boundaries. Its lifecycle details intentionally stay encapsulated.
    @MainActor
    public final class Coordinator {
        fileprivate let environment = AppKitEnvironmentState()
        fileprivate let dismantle: DismantleNSView

        fileprivate init(dismantle: @escaping DismantleNSView) {
            self.dismantle = dismantle
        }
    }

    private let make: MakeNSView
    private let update: UpdateNSView
    private let dismantle: DismantleNSView
    private let measure: MeasureNSView?

    /// Creates a bridge whose closures receive the full representable context.
    public init(
        make: @escaping MakeNSView,
        update: @escaping UpdateNSView = { _, _ in },
        dismantle: @escaping DismantleNSView = { _ in },
        sizeThatFits: MeasureNSView? = nil
    ) {
        self.make = make
        self.update = update
        self.dismantle = dismantle
        measure = sizeThatFits
    }

    /// Creates a bridge when the representable context is not needed.
    public init(
        make: @escaping @MainActor () -> ViewType,
        update: @escaping @MainActor (ViewType) -> Void = { _ in },
        dismantle: @escaping DismantleNSView = { _ in },
        sizeThatFits: (@MainActor (ProposedViewSize, ViewType) -> CGSize?)? = nil
    ) {
        let contextualMeasure: MeasureNSView?
        if let sizeThatFits {
            contextualMeasure = { proposal, view, _ in
                sizeThatFits(proposal, view)
            }
        } else {
            contextualMeasure = nil
        }
        self.init(
            make: { (_: Context) -> ViewType in make() },
            update: { (view: ViewType, _: Context) in update(view) },
            dismantle: dismantle,
            sizeThatFits: contextualMeasure
        )
    }

    /// Wraps an already-created view instance.
    ///
    /// Prefer the factory initializer when SwiftUI may create multiple bridge
    /// identities. This initializer is useful when ownership is external.
    public init(
        _ view: ViewType,
        update: @escaping @MainActor (ViewType) -> Void = { _ in },
        dismantle: @escaping DismantleNSView = { _ in },
        sizeThatFits: (@MainActor (ProposedViewSize, ViewType) -> CGSize?)? = nil
    ) {
        self.init(
            make: { view },
            update: update,
            dismantle: dismantle,
            sizeThatFits: sizeThatFits
        )
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(dismantle: dismantle)
    }

    public func makeNSView(context: Context) -> ViewType {
        let view = make(context)
        context.coordinator.environment.update(view, environment: context.environment) { _ in }
        return view
    }

    public func updateNSView(_ nsView: ViewType, context: Context) {
        context.coordinator.environment.update(nsView, environment: context.environment) {
            update($0, context)
        }
    }

    public static func dismantleNSView(
        _ nsView: ViewType,
        coordinator: Coordinator
    ) {
        coordinator.environment.dismantle()
        coordinator.dismantle(nsView)
    }

    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: ViewType,
        context: Context
    ) -> CGSize? {
        measure?(proposal, nsView, context)
    }
}

public extension AppKitView {
    /// Adds an update operation after the bridge's existing update operation.
    func configure(
        _ body: @escaping @MainActor (ViewType) -> Void
    ) -> Self {
        Self(
            make: make,
            update: { view, context in
                update(view, context)
                body(view)
            },
            dismantle: dismantle,
            sizeThatFits: measure
        )
    }

    /// Replaces the bridge's measurement strategy.
    func measuring(
        _ body: @escaping MeasureNSView
    ) -> Self {
        Self(
            make: make,
            update: update,
            dismantle: dismantle,
            sizeThatFits: body
        )
    }

    /// Uses AppKit's constraint-based fitting size. Supply `measuring` for custom proposals.
    func measuringWithAutoLayout() -> Self {
        measuring { _, view, _ in view.fittingSize }
    }

    /// Adds a teardown operation after the bridge's existing operation.
    func onDismantle(
        _ body: @escaping DismantleNSView
    ) -> Self {
        Self(
            make: make,
            update: update,
            dismantle: { view in
                dismantle(view)
                body(view)
            },
            sizeThatFits: measure
        )
    }
}

extension AppKitView: AppKitViewConfiguring {
    public typealias AppKitViewType = ViewType

    /// Appends AppKit configuration to each update.
    public func configureAppKit(
        _ body: @escaping @MainActor (ViewType) -> Void
    ) -> Self {
        configure(body)
    }
}

public extension AppKitView where ViewType: NSTextField {
    /// Sets label text that follows SwiftUI's environment locale.
    func text(localized resource: LocalizedStringResource) -> Self {
        Self(
            make: make,
            update: { view, context in
                update(view, context)
                view.stringValue = AppKitDisplayText.localized(resource)
                    .resolve(in: context.environment.locale)
            },
            dismantle: dismantle,
            sizeThatFits: measure
        )
    }

    /// Sets label text without localization.
    func text(verbatim text: String) -> Self {
        self.text(text)
    }
}
#endif
