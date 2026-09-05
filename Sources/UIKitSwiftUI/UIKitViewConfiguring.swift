import SwiftUI
import UIKit

/// A SwiftUI bridge that supports configuration of its concrete UIKit view.
@MainActor
public protocol UIKitViewConfiguring: View {
    associatedtype UIKitViewType: UIView

    /// Appends configuration to run on each update, after existing configuration.
    ///
    /// Use this for UIKit-specific properties. Do not replace a bridge-owned
    /// delegate or data source, or write properties controlled by a binding.
    /// Configuration may run repeatedly; install resources in `make` instead.
    func configureUIKit(
        _ configure: @escaping @MainActor (UIKitViewType) -> Void
    ) -> Self
}

public extension UIKitViewConfiguring where UIKitViewType: UILabel {
    /// Sets the label's unlocalized text.
    func text(_ text: String?) -> Self {
        configureUIKit { $0.text = text }
    }

    /// Sets an explicit UIKit line count, overriding the inherited line limit.
    /// Pass zero for an unlimited number of lines.
    func numberOfLines(_ count: Int) -> Self {
        precondition(count >= 0, "The number of lines must not be negative.")
        return configureUIKit { $0.numberOfLines = count }
    }
}

public extension UIKitViewConfiguring where UIKitViewType: UITextField {
    /// Sets the UIKit text field's border appearance.
    func textFieldBorderStyle(_ style: UITextField.BorderStyle) -> Self {
        configureUIKit { $0.borderStyle = style }
    }

    /// Specifies when the UIKit text field displays its clear button.
    func textFieldClearButtonMode(_ mode: UITextField.ViewMode) -> Self {
        configureUIKit { $0.clearButtonMode = mode }
    }

    /// Specifies whether the text field obscures its contents.
    func textFieldSecureTextEntry(_ isSecure: Bool = true) -> Self {
        configureUIKit {
            if $0.isSecureTextEntry != isSecure {
                $0.isSecureTextEntry = isSecure
            }
        }
    }
}

public extension UIKitViewConfiguring where UIKitViewType: UITextField {
    /// Sets a UIKit keyboard type without shadowing SwiftUI's modifier.
    func uiKitKeyboardType(_ type: UIKeyboardType) -> Self {
        configureUIKit { $0.keyboardType = type }
    }

    /// Describes the semantic content expected by UIKit's text input.
    func uiKitTextContentType(_ type: UITextContentType?) -> Self {
        configureUIKit { $0.textContentType = type }
    }

    /// Sets the label of the UIKit return key.
    func uiKitReturnKeyType(_ type: UIReturnKeyType) -> Self {
        configureUIKit { $0.returnKeyType = type }
    }
}

public extension UIKitViewConfiguring where UIKitViewType: UITextView {
    /// Sets a UIKit keyboard type without shadowing SwiftUI's modifier.
    func uiKitKeyboardType(_ type: UIKeyboardType) -> Self {
        configureUIKit { $0.keyboardType = type }
    }

    /// Describes the semantic content expected by UIKit's text input.
    func uiKitTextContentType(_ type: UITextContentType?) -> Self {
        configureUIKit { $0.textContentType = type }
    }

    /// Sets the label of the UIKit return key.
    func uiKitReturnKeyType(_ type: UIReturnKeyType) -> Self {
        configureUIKit { $0.returnKeyType = type }
    }
}

public extension UIKitViewConfiguring where UIKitViewType: UIDatePicker {
    /// Sets the UIKit presentation style of the date picker.
    func uiKitDatePickerStyle(_ style: UIDatePickerStyle) -> Self {
        configureUIKit { $0.preferredDatePickerStyle = style }
    }
}

public extension UIKitViewConfiguring where UIKitViewType: UISlider {
    /// Specifies whether dragging delivers intermediate slider values.
    func sliderContinuousUpdates(_ isContinuous: Bool = true) -> Self {
        configureUIKit { $0.isContinuous = isContinuous }
    }
}
