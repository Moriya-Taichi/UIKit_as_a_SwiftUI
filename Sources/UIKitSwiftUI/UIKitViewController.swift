#if canImport(UIKit)
import SwiftUI
import UIKit

/// A lifecycle-aware SwiftUI representation of any `UIViewController` subclass.
///
/// View controllers cannot correctly be embedded with `UIViewRepresentable`.
/// This bridge uses `UIViewControllerRepresentable`, preserving containment and
/// appearance callbacks while matching the closure API of `UIKitView`.
@MainActor
public struct UIKitViewController<ControllerType: UIViewController>: UIViewControllerRepresentable {
    public typealias UIViewControllerType = ControllerType
    public typealias MakeController = @MainActor (Context) -> ControllerType
    public typealias UpdateController = @MainActor (ControllerType, Context) -> Void
    public typealias DismantleController = @MainActor (ControllerType) -> Void
    public typealias MeasureController = @MainActor (
        ProposedViewSize,
        ControllerType,
        Context
    ) -> CGSize?

    public final class Coordinator {
        fileprivate let dismantle: DismantleController

        fileprivate init(dismantle: @escaping DismantleController) {
            self.dismantle = dismantle
        }
    }

    private let make: MakeController
    private let update: UpdateController
    private let dismantle: DismantleController
    private let measure: MeasureController?

    public init(
        make: @escaping MakeController,
        update: @escaping UpdateController = { _, _ in },
        dismantle: @escaping DismantleController = { _ in },
        sizeThatFits: MeasureController? = nil
    ) {
        self.make = make
        self.update = update
        self.dismantle = dismantle
        measure = sizeThatFits
    }

    public init(
        make: @escaping @MainActor () -> ControllerType,
        update: @escaping @MainActor (ControllerType) -> Void = { _ in },
        dismantle: @escaping DismantleController = { _ in },
        sizeThatFits: (@MainActor (ProposedViewSize, ControllerType) -> CGSize?)? = nil
    ) {
        let contextualMeasure: MeasureController?
        if let sizeThatFits {
            contextualMeasure = { proposal, controller, _ in
                sizeThatFits(proposal, controller)
            }
        } else {
            contextualMeasure = nil
        }
        self.init(
            make: { (_: Context) -> ControllerType in make() },
            update: { (controller: ControllerType, _: Context) in
                update(controller)
            },
            dismantle: dismantle,
            sizeThatFits: contextualMeasure
        )
    }

    public init(
        _ controller: ControllerType,
        update: @escaping @MainActor (ControllerType) -> Void = { _ in },
        dismantle: @escaping DismantleController = { _ in },
        sizeThatFits: (@MainActor (ProposedViewSize, ControllerType) -> CGSize?)? = nil
    ) {
        self.init(
            make: { controller },
            update: update,
            dismantle: dismantle,
            sizeThatFits: sizeThatFits
        )
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(dismantle: dismantle)
    }

    public func makeUIViewController(context: Context) -> ControllerType {
        make(context)
    }

    public func updateUIViewController(
        _ uiViewController: ControllerType,
        context: Context
    ) {
        update(uiViewController, context)
    }

    public static func dismantleUIViewController(
        _ uiViewController: ControllerType,
        coordinator: Coordinator
    ) {
        coordinator.dismantle(uiViewController)
    }

    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiViewController: ControllerType,
        context: Context
    ) -> CGSize? {
        measure?(proposal, uiViewController, context)
    }
}

public extension UIKitViewController {
    func configure(
        _ body: @escaping @MainActor (ControllerType) -> Void
    ) -> Self {
        Self(
            make: make,
            update: { controller, context in
                update(controller, context)
                body(controller)
            },
            dismantle: dismantle,
            sizeThatFits: measure
        )
    }

    func measuring(
        _ body: @escaping MeasureController
    ) -> Self {
        Self(
            make: make,
            update: update,
            dismantle: dismantle,
            sizeThatFits: body
        )
    }

    func onDismantle(
        _ body: @escaping DismantleController
    ) -> Self {
        Self(
            make: make,
            update: update,
            dismantle: { controller in
                dismantle(controller)
                body(controller)
            },
            sizeThatFits: measure
        )
    }
}

public extension UIKitViewController {
    /// Appends UIKit controller configuration to each update.
    func configureUIKit(
        _ body: @escaping @MainActor (ControllerType) -> Void
    ) -> Self {
        configure(body)
    }
}
#endif
