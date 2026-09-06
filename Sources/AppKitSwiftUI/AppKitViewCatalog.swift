#if os(macOS)
import AppKit
import SwiftUI

/// Convenience factories. Any other NSView subclass can use AppKitView(make:).
public enum AppKitViewCatalog {
    @MainActor public static func label(_ text: String = "") -> AppKitView<NSTextField> {
        AppKitView(make: { NSTextField(labelWithString: "") }).text(verbatim: text)
    }

    @MainActor public static func imageView(image: NSImage? = nil) -> AppKitView<NSImageView> {
        AppKitView(make: { NSImageView() }).configureAppKit { $0.image = image }
    }

    @MainActor public static func progressIndicator(value: Double, in bounds: ClosedRange<Double> = 0...1) -> AppKitView<NSProgressIndicator> {
        AppKitView(make: { NSProgressIndicator() }).configureAppKit {
            $0.isIndeterminate = false
            $0.minValue = bounds.lowerBound
            $0.maxValue = bounds.upperBound
            $0.doubleValue = value
        }
    }

    @MainActor public static func activityIndicator(isAnimating: Bool = true) -> AppKitView<NSProgressIndicator> {
        AppKitView(make: { NSProgressIndicator() }).configureAppKit {
            $0.style = .spinning
            $0.isIndeterminate = true
            isAnimating ? $0.startAnimation(nil) : $0.stopAnimation(nil)
        }
    }

    @MainActor public static func scrollView() -> AppKitView<AppKitManagedScrollView> {
        AppKitView(make: { AppKitManagedScrollView() })
    }

    @MainActor public static func visualEffectView(material: NSVisualEffectView.Material = .sidebar) -> AppKitView<NSVisualEffectView> {
        AppKitView(make: { NSVisualEffectView() }).configureAppKit { $0.material = material }
    }
}
#endif
