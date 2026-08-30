# Design and support policy

## What “all UIKit” means

`UIViewRepresentable` can only create and manage `UIView` instances. A wrapper
per concrete UIKit class would always lag behind the SDK and would duplicate
the same lifecycle code. `UIKitView<ViewType>` instead places the exhaustive
boundary at `ViewType: UIView`; therefore every public or application-defined
subclass is accepted while retaining its concrete type.

The same rule applies to `UIControl` through `UIKitControl`. View controllers
are exhaustive under `ControllerType: UIViewController`, but use
`UIViewControllerRepresentable` because controller containment cannot be
implemented correctly by wrapping only the controller's root view.

Non-view UIKit values such as images, colors, fonts, configurations, layout
objects, interactions, gestures, delegates, and data sources are inputs to the
bridge rather than representables themselves.

## Lifecycle contract

1. `make` creates exactly one UIKit instance for a SwiftUI representable
   identity.
2. `update` synchronizes current SwiftUI state into that instance.
3. A coordinator owns delegates, data sources, and actions that must survive
   value-type SwiftUI view recreation.
4. `dismantle` disconnects callbacks and releases external resources.
5. `sizeThatFits` participates in SwiftUI layout when a caller supplies a
   measurement strategy.

Every bridge is isolated to `MainActor`, matching UIKit's threading model.

## SDK compatibility

The package deployment target is iOS 16 and Mac Catalyst 16. The generic
bridges do not switch on OS version and do not reflect over SDK symbols. A
client may instantiate any view visible in the SDK it compiles against and use
normal `@available` checks for SDK-specific types. The only SDK-gated API in
the package is `UIKitViewCatalog.contentUnavailableView`, marked
`@available(iOS 17.0, macCatalyst 17.0, *)`; everything else compiles for
iOS 16.

CI builds the same source with both ends of the supported SDK range and runs
the tests on the minimum deployment target:

- Xcode 16 / iOS 18 SDK
- Xcode 27 / iOS 27 SDK
- Xcode 16 with a downloaded iOS 16.4 simulator runtime, to run the tests on
  the minimum deployment target

References:

- [UIViewRepresentable](https://developer.apple.com/documentation/swiftui/uiviewrepresentable)
- [UIKit](https://developer.apple.com/documentation/uikit)
- [iOS 18 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-18-release-notes)
- [iOS 26 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-26-release-notes)
- [iOS 27 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes)

