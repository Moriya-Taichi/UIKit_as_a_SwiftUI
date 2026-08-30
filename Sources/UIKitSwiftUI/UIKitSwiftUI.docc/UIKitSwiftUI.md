# ``UIKitSwiftUI``

Integrate any UIKit view or view controller into SwiftUI without erasing its
concrete type.

## Overview

Use ``UIKitView`` for every `UIView` subclass. Use
``UIKitCoordinatedView`` when the view needs a delegate, data source, or other
lifecycle-bound object. UIKit controls can use ``UIKitControl`` for automatic
target-action management.

View controllers use ``UIKitViewController`` or
``UIKitCoordinatedViewController`` so UIKit containment and appearance
callbacks remain correct.

Interactive views can instead be driven by observable models, in the style of
WebKit's SwiftUI `WebPage`. The model owns the data, focus, selection, and
policy decisions; the bridge only displays it. Delegate notifications arrive
through the model's `events` stream, and table and collection data comes from
``UIKitListModel``, so callers never implement a UIKit data source. That layer
builds on `@Observable` and requires iOS 17.

The package deploys to iOS 16 and Mac Catalyst 16. Every bridge and catalog
factory is available from that target except
`UIKitViewCatalog.contentUnavailableView`, which wraps an iOS 17 view, and the
observable-model layer — the `*Model` types, the `*Deciding` protocols,
``UIKitTableView``, ``UIKitCollectionView``, and each bridge's `init(model:)`
— which are all marked `@available(iOS 17.0, macCatalyst 17.0, *)`.

## Topics

### Universal bridges

- ``UIKitView``
- ``UIKitCoordinatedView``
- ``UIKitControl``
- ``UIKitViewController``
- ``UIKitCoordinatedViewController``
- ``UIKitBridge``

### Binding-backed controls

- ``UIKitSlider``
- ``UIKitSwitch``
- ``UIKitStepper``
- ``UIKitPageControl``
- ``UIKitSegmentedControl``
- ``UIKitDatePicker``
- ``UIKitColorWell``
- ``UIKitButton``
- ``UIKitTextField``
- ``UIKitTextView``
- ``UIKitSearchBar``

### Observable models

- ``UIKitTextFieldModel``
- ``UIKitTextViewModel``
- ``UIKitSearchBarModel``
- ``UIKitListModel``
- ``UIKitTableView``
- ``UIKitCollectionView``

### Policy deciders

- ``UIKitTextFieldDeciding``
- ``UIKitTextViewDeciding``
- ``UIKitSearchBarDeciding``

### Configuration

- ``UIKitAccessibility``
- ``UIKitViewCatalog``

