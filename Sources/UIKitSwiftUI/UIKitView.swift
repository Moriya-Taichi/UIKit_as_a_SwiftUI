import SwiftUI
import UIKit

/// A lifecycle-aware SwiftUI representation of any `UIView` subclass.
///
/// `UIKitView` is the universal entry point of this package. Because the view
/// type is generic, it also supports UIKit view classes introduced by a newer
/// SDK without requiring a package release.
@MainActor
public struct UIKitView<ViewType: UIView>: UIViewRepresentable {
    public typealias UIViewType = ViewType
    public typealias MakeUIView = @MainActor (Context) -> ViewType
    public typealias UpdateUIView = @MainActor (ViewType, Context) -> Void
    public typealias DismantleUIView = @MainActor (ViewType) -> Void
    public typealias MeasureUIView = @MainActor (
        ProposedViewSize,
        ViewType,
        Context
    ) -> CGSize?

    /// The coordinator is public so `UIKitView` remains usable across module
    /// boundaries. Its lifecycle details intentionally stay encapsulated.
    @MainActor
    public final class Coordinator {
        fileprivate let environment = UIKitEnvironmentState()
        fileprivate let dismantle: DismantleUIView

        fileprivate init(dismantle: @escaping DismantleUIView) {
            self.dismantle = dismantle
        }
    }

    private let make: MakeUIView
    private let update: UpdateUIView
    private let dismantle: DismantleUIView
    private let measure: MeasureUIView?

    /// Creates a bridge whose closures receive the full representable context.
    public init(
        make: @escaping MakeUIView,
        update: @escaping UpdateUIView = { _, _ in },
        dismantle: @escaping DismantleUIView = { _ in },
        sizeThatFits: MeasureUIView? = nil
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
        dismantle: @escaping DismantleUIView = { _ in },
        sizeThatFits: (@MainActor (ProposedViewSize, ViewType) -> CGSize?)? = nil
    ) {
        let contextualMeasure: MeasureUIView?
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
        dismantle: @escaping DismantleUIView = { _ in },
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

    public func makeUIView(context: Context) -> ViewType {
        let view = make(context)
        context.coordinator.environment.update(view, environment: context.environment) { _ in }
        return view
    }

    public func updateUIView(_ uiView: ViewType, context: Context) {
        context.coordinator.environment.update(uiView, environment: context.environment) {
            update($0, context)
        }
    }

    public static func dismantleUIView(
        _ uiView: ViewType,
        coordinator: Coordinator
    ) {
        coordinator.environment.dismantle()
        coordinator.dismantle(uiView)
    }

    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: ViewType,
        context: Context
    ) -> CGSize? {
        measure?(proposal, uiView, context)
    }
}

public extension UIKitView {
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
        _ body: @escaping MeasureUIView
    ) -> Self {
        Self(
            make: make,
            update: update,
            dismantle: dismantle,
            sizeThatFits: body
        )
    }

    /// Measures the UIKit view with `systemLayoutSizeFitting(_:)`.
    func measuringWithAutoLayout() -> Self {
        measuring { proposal, view, _ in
            let target = CGSize(
                width: proposal.width ?? UIView.layoutFittingCompressedSize.width,
                height: proposal.height ?? UIView.layoutFittingCompressedSize.height
            )
            return view.systemLayoutSizeFitting(target)
        }
    }

    /// Adds a teardown operation after the bridge's existing operation.
    func onDismantle(
        _ body: @escaping DismantleUIView
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

extension UIKitView: UIKitViewConfiguring {
    public typealias UIKitViewType = ViewType

    /// Appends UIKit configuration to each update.
    public func configureUIKit(
        _ body: @escaping @MainActor (ViewType) -> Void
    ) -> Self {
        configure(body)
    }
}

public extension UIKitView where ViewType: UILabel {
    /// Sets label text that follows SwiftUI's environment locale.
    func text(localized resource: LocalizedStringResource) -> Self {
        Self(
            make: make,
            update: { view, context in
                update(view, context)
                view.text = UIKitDisplayText.localized(resource)
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
