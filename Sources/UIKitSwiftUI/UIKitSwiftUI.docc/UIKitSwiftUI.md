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

