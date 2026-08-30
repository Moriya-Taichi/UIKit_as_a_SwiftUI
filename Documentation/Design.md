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

## Observable models, deciders, and event streams

Text input and list data follow the split WebKit uses for its SwiftUI
`WebPage` / `WebView` pair. An `@Observable` `@MainActor` model owns the data,
the desired focus, the selection, and the policy; the representable is only a
bridge that synchronizes that model with the UIKit instance. The model types
are `UIKitTextFieldModel`, `UIKitTextViewModel`, `UIKitSearchBarModel`, and
`UIKitListModel`; the bridges that display them are `UIKitTextField`,
`UIKitTextView`, `UIKitSearchBar`, `UIKitTableView`, and
`UIKitCollectionView`.

Policy delegate methods become `*Deciding` protocols rather than closures:
`UIKitTextFieldDeciding`, `UIKitTextViewDeciding`, `UIKitSearchBarDeciding`.
Each is a `@MainActor` protocol whose requirements return a decision and carry
a permissive default, so a conforming type implements only the checks it needs
and inherits `true` for the rest. A decider is injected at model
initialization and owned by the model; the bridge asks the model, never the
decider.

Notification-style delegate callbacks become elements of one `AsyncStream`
exposed as `model.events`. The stream is single-consumer: iterate it from
exactly one task, because a second consumer competes for elements instead of
receiving its own copy. The continuation finishes when the model
deinitializes.

`UIKitListModel` owns the sections and the items. `UIKitTableView` and
`UIKitCollectionView` translate that data into an
`NSDiffableDataSourceSnapshot` and apply it to a diffable data source they
own, so callers never implement `UITableViewDataSource` or
`UICollectionViewDataSource`; they only describe how an item becomes a cell.
Item identity is value identity: an item whose value changes is a new
identifier to the diff, so it appears as a removal and an insertion rather
than an in-place update. Use an item type that carries only stable identity
when a change must read as an update.

The binding and closure initializers remain as the lighter alternative for
cases that need no model, and the two modes never mix within one bridge
instance. An instance created with `model:` ignores the binding parameters and
routes every delegate callback through the model; an instance created with
bindings never touches a model.

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
- Xcode 16 with a downloaded iOS 16.4 simulator runtime

References:

- [UIViewRepresentable](https://developer.apple.com/documentation/swiftui/uiviewrepresentable)
- [UIKit](https://developer.apple.com/documentation/uikit)
- [WebPage](https://developer.apple.com/documentation/webkit/webpage)
- [iOS 18 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-18-release-notes)
- [iOS 26 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-26-release-notes)
- [iOS 27 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes)

