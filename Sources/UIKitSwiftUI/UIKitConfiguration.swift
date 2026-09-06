#if canImport(UIKit)
import SwiftUI
import UIKit

/// UIKit accessibility values applied during each SwiftUI update pass.
public struct UIKitAccessibility {
    public var identifier: String?
    public var label: String?
    public var hint: String?
    public var value: String?
    public var traits: UIAccessibilityTraits?

    public init(
        identifier: String? = nil,
        label: String? = nil,
        hint: String? = nil,
        value: String? = nil,
        traits: UIAccessibilityTraits? = nil
    ) {
        self.identifier = identifier
        self.label = label
        self.hint = hint
        self.value = value
        self.traits = traits
    }
}

public extension UIKitView {
    /// Assigns a UIKit property on every SwiftUI update pass.
    func setting<Value>(
        _ keyPath: ReferenceWritableKeyPath<ViewType, Value>,
        to value: Value
    ) -> Self {
        configure { $0[keyPath: keyPath] = value }
    }

    /// Applies native UIKit accessibility metadata without replacing the view.
    func accessibility(_ values: UIKitAccessibility) -> Self {
        configure { view in
            view.isAccessibilityElement = true
            if let identifier = values.identifier {
                view.accessibilityIdentifier = identifier
            }
            if let label = values.label {
                view.accessibilityLabel = label
            }
            if let hint = values.hint {
                view.accessibilityHint = hint
            }
            if let value = values.value {
                view.accessibilityValue = value
            }
            if let traits = values.traits {
                view.accessibilityTraits = traits
            }
        }
    }
}

public extension UIKitViewController {
    /// Assigns a UIKit controller property on every SwiftUI update pass.
    func setting<Value>(
        _ keyPath: ReferenceWritableKeyPath<ControllerType, Value>,
        to value: Value
    ) -> Self {
        configure { $0[keyPath: keyPath] = value }
    }
}
#endif
