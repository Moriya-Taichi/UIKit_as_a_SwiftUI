#if canImport(UIKit)
import SwiftUI
import UIKit

/// Factory conveniences for UIKit views with non-uniform initializers.
///
/// The catalog is intentionally ergonomic rather than exhaustive. Every
/// concrete `UIView` remains supported by the generic `UIKitView` initializer.
public enum UIKitViewCatalog {}

public extension UIKitViewCatalog {
    @MainActor
    static func view(
        configure: @escaping @MainActor (UIView) -> Void = { _ in }
    ) -> UIKitView<UIView> {
        UIKitView(make: UIView.init, update: configure)
    }

    @MainActor
    static func label(
        configure: @escaping @MainActor (UILabel) -> Void = { _ in }
    ) -> UIKitView<UILabel> {
        UIKitView(make: UILabel.init, update: configure)
    }

    @MainActor
    static func imageView(
        image: UIImage? = nil,
        configure: @escaping @MainActor (UIImageView) -> Void = { _ in }
    ) -> UIKitView<UIImageView> {
        UIKitView(
            make: { UIImageView(image: image) },
            update: { imageView in
                imageView.image = image
                configure(imageView)
            }
        )
    }

    @MainActor
    static func activityIndicator(
        style: UIActivityIndicatorView.Style = .medium,
        isAnimating: Bool = true,
        configure: @escaping @MainActor (UIActivityIndicatorView) -> Void = { _ in }
    ) -> UIKitView<UIActivityIndicatorView> {
        UIKitView(
            make: { UIActivityIndicatorView(style: style) },
            update: { indicator in
                indicator.style = style
                isAnimating ? indicator.startAnimating() : indicator.stopAnimating()
                configure(indicator)
            }
        )
    }

    @MainActor
    static func progressView(
        progress: Float,
        style: UIProgressView.Style = .default,
        configure: @escaping @MainActor (UIProgressView) -> Void = { _ in }
    ) -> UIKitView<UIProgressView> {
        UIKitView(
            make: { UIProgressView(progressViewStyle: style) },
            update: { progressView in
                progressView.progress = progress
                configure(progressView)
            }
        )
    }

    @MainActor
    static func visualEffectView(
        effect: UIVisualEffect? = nil,
        configure: @escaping @MainActor (UIVisualEffectView) -> Void = { _ in }
    ) -> UIKitView<UIVisualEffectView> {
        UIKitView(
            make: { UIVisualEffectView(effect: effect) },
            update: { visualEffectView in
                visualEffectView.effect = effect
                configure(visualEffectView)
            }
        )
    }

    @MainActor
    static func stackView(
        axis: NSLayoutConstraint.Axis = .horizontal,
        alignment: UIStackView.Alignment = .fill,
        distribution: UIStackView.Distribution = .fill,
        spacing: CGFloat = 0,
        configure: @escaping @MainActor (UIStackView) -> Void = { _ in }
    ) -> UIKitView<UIStackView> {
        UIKitView(
            make: UIStackView.init,
            update: { stackView in
                stackView.axis = axis
                stackView.alignment = alignment
                stackView.distribution = distribution
                stackView.spacing = spacing
                configure(stackView)
            }
        )
    }

    @MainActor
    static func scrollView(
        configure: @escaping @MainActor (UIScrollView) -> Void = { _ in }
    ) -> UIKitView<UIScrollView> {
        UIKitView(make: UIScrollView.init, update: configure)
    }

    @MainActor
    static func tableView(
        style: UITableView.Style = .plain,
        configure: @escaping @MainActor (UITableView) -> Void = { _ in }
    ) -> UIKitView<UITableView> {
        UIKitView(
            make: { UITableView(frame: .zero, style: style) },
            update: configure
        )
    }

    @MainActor
    static func collectionView(
        layout: @escaping @MainActor () -> UICollectionViewLayout,
        configure: @escaping @MainActor (UICollectionView) -> Void = { _ in }
    ) -> UIKitView<UICollectionView> {
        UIKitView(
            make: {
                UICollectionView(
                    frame: .zero,
                    collectionViewLayout: layout()
                )
            },
            update: configure
        )
    }

    @MainActor
    static func pickerView(
        configure: @escaping @MainActor (UIPickerView) -> Void = { _ in }
    ) -> UIKitView<UIPickerView> {
        UIKitView(make: UIPickerView.init, update: configure)
    }

    @MainActor
    static func calendarView(
        configure: @escaping @MainActor (UICalendarView) -> Void = { _ in }
    ) -> UIKitView<UICalendarView> {
        UIKitView(make: UICalendarView.init, update: configure)
    }

    @MainActor
    static func listContentView(
        configuration: UIListContentConfiguration,
        configure: @escaping @MainActor (UIListContentView) -> Void = { _ in }
    ) -> UIKitView<UIListContentView> {
        UIKitView(
            make: { UIListContentView(configuration: configuration) },
            update: { contentView in
                contentView.configuration = configuration
                configure(contentView)
            }
        )
    }

    @available(iOS 17.0, macCatalyst 17.0, *)
    @MainActor
    static func contentUnavailableView(
        configuration: UIContentUnavailableConfiguration,
        configure: @escaping @MainActor (UIContentUnavailableView) -> Void = { _ in }
    ) -> UIKitView<UIContentUnavailableView> {
        UIKitView(
            make: { UIContentUnavailableView(configuration: configuration) },
            update: { contentView in
                contentView.configuration = configuration
                configure(contentView)
            }
        )
    }

    @MainActor
    static func navigationBar(
        configure: @escaping @MainActor (UINavigationBar) -> Void = { _ in }
    ) -> UIKitView<UINavigationBar> {
        UIKitView(make: UINavigationBar.init, update: configure)
    }

    @MainActor
    static func tabBar(
        configure: @escaping @MainActor (UITabBar) -> Void = { _ in }
    ) -> UIKitView<UITabBar> {
        UIKitView(make: UITabBar.init, update: configure)
    }

    @MainActor
    static func toolbar(
        configure: @escaping @MainActor (UIToolbar) -> Void = { _ in }
    ) -> UIKitView<UIToolbar> {
        UIKitView(make: UIToolbar.init, update: configure)
    }

    @MainActor
    static func searchTextField(
        configure: @escaping @MainActor (UISearchTextField) -> Void = { _ in }
    ) -> UIKitView<UISearchTextField> {
        UIKitView(make: UISearchTextField.init, update: configure)
    }

    @MainActor
    static func refreshControl(
        onRefresh: @escaping @MainActor (UIRefreshControl) -> Void,
        configure: @escaping @MainActor (UIRefreshControl) -> Void = { _ in }
    ) -> UIKitControl<UIRefreshControl> {
        UIKitControl(
            make: UIRefreshControl.init,
            events: .valueChanged,
            update: { control, _ in configure(control) },
            onEvent: onRefresh
        )
    }
}
#endif
