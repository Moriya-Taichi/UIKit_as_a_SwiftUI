#if os(macOS)
import AppKit
import SwiftUI

@MainActor
public protocol AppKitViewConfiguring: View {
    associatedtype AppKitViewType: NSView
    func configureAppKit(_ body: @escaping @MainActor (AppKitViewType) -> Void) -> Self
}

public extension AppKitViewConfiguring {
    func setting<Value>(
        _ keyPath: ReferenceWritableKeyPath<AppKitViewType, Value>, to value: Value
    ) -> Self {
        configureAppKit { $0[keyPath: keyPath] = value }
    }
}

public extension AppKitViewConfiguring where AppKitViewType: NSTextField {
    func text(_ text: String) -> Self {
        configureAppKit { $0.stringValue = text }
    }

    func numberOfLines(_ count: Int) -> Self {
        precondition(count >= 0, "Line count must not be negative")
        return configureAppKit { $0.maximumNumberOfLines = count }
    }

    func textFieldBezelStyle(_ style: NSTextField.BezelStyle) -> Self {
        configureAppKit { $0.isBezeled = true; $0.bezelStyle = style }
    }

    func textFieldDrawsBackground(_ drawsBackground: Bool) -> Self {
        configureAppKit { $0.drawsBackground = drawsBackground }
    }
}

public extension AppKitViewConfiguring where AppKitViewType: NSButton {
    func appKitBezelStyle(_ style: NSButton.BezelStyle) -> Self {
        configureAppKit { $0.bezelStyle = style }
    }
}

public extension AppKitViewConfiguring where AppKitViewType: NSSlider {
    func sliderContinuousUpdates(_ continuous: Bool) -> Self {
        configureAppKit { $0.isContinuous = continuous }
    }
}

public extension AppKitViewConfiguring where AppKitViewType: NSDatePicker {
    func appKitDatePickerStyle(_ style: NSDatePicker.Style) -> Self {
        configureAppKit { $0.datePickerStyle = style }
    }
}

public extension AppKitViewController {
    func setting<Value>(
        _ keyPath: ReferenceWritableKeyPath<ControllerType, Value>, to value: Value
    ) -> Self {
        configureAppKit { $0[keyPath: keyPath] = value }
    }
}
#endif
