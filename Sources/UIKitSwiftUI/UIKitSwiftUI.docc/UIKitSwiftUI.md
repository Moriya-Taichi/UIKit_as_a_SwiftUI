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
``UIKitListModel``, so callers never implement a UIKit data source.

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

