#if os(macOS)
import AppKit
import SwiftUI

@MainActor
final class AppKitActionTarget: NSObject {
    var handler: (NSControl) -> Void = { _ in }

    @objc func invoke(_ sender: NSControl) { handler(sender) }
}

/// A target-action bridge for any NSControl subclass.
/// Owns the single native target/action slot while mounted and restores it on teardown.
@MainActor
public struct AppKitControl<ControlType: NSControl>: NSViewRepresentable, AppKitViewConfiguring {
    public typealias AppKitViewType = ControlType
    public typealias UpdateControl = @MainActor (ControlType, Context) -> Void
    public typealias HandleEvent = @MainActor (ControlType) -> Void
    public typealias MeasureControl = @MainActor (ProposedViewSize, ControlType, Context) -> CGSize?

    @MainActor
    public final class Coordinator {
        fileprivate let environment = AppKitEnvironmentState()
        fileprivate let target = AppKitActionTarget()
        fileprivate weak var previousTarget: AnyObject?
        fileprivate var previousAction: Selector?

        fileprivate func install(on control: ControlType) {
            previousTarget = control.target
            previousAction = control.action
            attach(to: control)
        }

        fileprivate func attach(to control: ControlType) {
            control.target = target
            control.action = #selector(AppKitActionTarget.invoke(_:))
        }

        fileprivate func uninstall(from control: ControlType) {
            if control.target === target, control.action == #selector(AppKitActionTarget.invoke(_:)) {
                control.target = previousTarget
                control.action = previousAction
            }
            target.handler = { _ in }
            previousTarget = nil
            previousAction = nil
        }
    }

    private let make: @MainActor () -> ControlType
    private var update: UpdateControl
    private let onEvent: HandleEvent
    private let measure: MeasureControl?

    public init(
        make: @escaping @MainActor () -> ControlType,
        update: @escaping UpdateControl = { _, _ in },
        onEvent: @escaping HandleEvent = { _ in },
        sizeThatFits: MeasureControl? = nil
    ) {
        self.make = make
        self.update = update
        self.onEvent = onEvent
        measure = sizeThatFits
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public func makeNSView(context: Context) -> ControlType {
        let control = make()
        context.coordinator.install(on: control)
        updateNSView(control, context: context)
        return control
    }

    public func updateNSView(_ nsView: ControlType, context: Context) {
        context.coordinator.target.handler = { control in
            guard let control = control as? ControlType else { return }
            onEvent(control)
        }
        context.coordinator.environment.update(nsView, environment: context.environment) {
            update($0, context)
        }
        context.coordinator.attach(to: nsView)
    }

    public static func dismantleNSView(_ nsView: ControlType, coordinator: Coordinator) {
        (nsView as? NSColorWell)?.deactivate()
        coordinator.uninstall(from: nsView)
        coordinator.environment.dismantle()
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, nsView: ControlType, context: Context) -> CGSize? {
        measure?(proposal, nsView, context)
    }

    public func configureAppKit(_ body: @escaping @MainActor (ControlType) -> Void) -> Self {
        var copy = self
        let previous = update
        copy.update = { view, context in
            previous(view, context)
            body(view)
        }
        return copy
    }
}
#endif
