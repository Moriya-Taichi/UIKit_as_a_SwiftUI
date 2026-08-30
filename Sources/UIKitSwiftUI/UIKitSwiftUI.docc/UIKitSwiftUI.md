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

The package deploys to iOS 16 and Mac Catalyst 16. Every bridge and catalog
factory is available from that target except
`UIKitViewCatalog.contentUnavailableView`, which wraps an iOS 17 view and is
marked `@available(iOS 17.0, macCatalyst 17.0, *)`.

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

### Configuration

- ``UIKitAccessibility``
- ``UIKitViewCatalog``

