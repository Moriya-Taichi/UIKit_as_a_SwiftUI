import SwiftUI
import UIKit

/// A type-safe `UIViewRepresentable` for any `UIControl` subclass.
///
/// The bridge installs one `UIAction`, updates its handler without registering
/// duplicate targets, and removes it when SwiftUI dismantles the control.
@MainActor
public struct UIKitControl<ControlType: UIControl>: UIViewRepresentable {
    public typealias UIViewType = ControlType
    public typealias MakeControl = @MainActor () -> ControlType
    public typealias UpdateControl = @MainActor (ControlType, Context) -> Void
    public typealias HandleEvent = @MainActor (ControlType) -> Void
    public typealias MeasureControl = @MainActor (
        ProposedViewSize,
        ControlType,
        Context
    ) -> CGSize?

    @MainActor
    public final class Coordinator {
        fileprivate let environment = UIKitEnvironmentState()
        fileprivate var handler: HandleEvent
        fileprivate var action: UIAction?
        fileprivate weak var control: ControlType?
        fileprivate var events: UIControl.Event = []

        fileprivate init(handler: @escaping HandleEvent) {
            self.handler = handler
        }

        fileprivate func install(
            on control: ControlType,
            for events: UIControl.Event
        ) {
            uninstall()
            self.control = control
            self.events = events

            let action = UIAction { [weak self, weak control] _ in
                guard let self, let control else { return }
                self.handler(control)
            }
            self.action = action
            control.addAction(action, for: events)
        }

        fileprivate func uninstall() {
            if let action, let control {
                control.removeAction(action, for: events)
            }
            action = nil
            control = nil
            events = []
        }
    }

    private let make: MakeControl
    private let events: UIControl.Event
    private var update: UpdateControl
    private let onEvent: HandleEvent
    private let measure: MeasureControl?

    public init(
        make: @escaping MakeControl,
        events: UIControl.Event = .primaryActionTriggered,
        update: @escaping UpdateControl = { _, _ in },
        onEvent: @escaping HandleEvent = { _ in },
        sizeThatFits: MeasureControl? = nil
    ) {
        self.make = make
        self.events = events
        self.update = update
        self.onEvent = onEvent
        measure = sizeThatFits
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(handler: onEvent)
    }

    public func makeUIView(context: Context) -> ControlType {
        let control = make()
        context.coordinator.install(on: control, for: events)
        context.coordinator.environment.update(control, environment: context.environment) {
            update($0, context)
        }
        return control
    }

    public func updateUIView(_ uiView: ControlType, context: Context) {
        context.coordinator.handler = onEvent
        if context.coordinator.events != events {
            context.coordinator.install(on: uiView, for: events)
        }
        context.coordinator.environment.update(uiView, environment: context.environment) {
            update($0, context)
        }
    }

    public static func dismantleUIView(
        _ uiView: ControlType,
        coordinator: Coordinator
    ) {
        coordinator.environment.dismantle()
        coordinator.uninstall()
    }

    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: ControlType,
        context: Context
    ) -> CGSize? {
        measure?(proposal, uiView, context)
    }
}

extension UIKitControl: UIKitViewConfiguring {
    public typealias UIKitViewType = ControlType

    /// Appends UIKit configuration to each update.
    public func configureUIKit(
        _ body: @escaping @MainActor (ControlType) -> Void
    ) -> Self {
        var copy = self
        let previous = update
        copy.update = { view, context in
            previous(view, context)
            body(view)
        }
        return copy
    }
}
