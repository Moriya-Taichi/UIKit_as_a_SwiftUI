import SwiftUI
import UIKit

/// A UIKit slider with a SwiftUI `Binding`.
@MainActor
public struct UIKitSlider: View {
    private let value: Binding<Float>
    private let range: ClosedRange<Float>
    private let isContinuous: Bool
    private let configure: @MainActor (UISlider) -> Void

    public init(
        value: Binding<Float>,
        in range: ClosedRange<Float> = 0 ... 1,
        isContinuous: Bool = true,
        configure: @escaping @MainActor (UISlider) -> Void = { _ in }
    ) {
        self.value = value
        self.range = range
        self.isContinuous = isContinuous
        self.configure = configure
    }

    public var body: some View {
        UIKitControl(
            make: UISlider.init,
            events: .valueChanged,
            update: { slider, _ in
                slider.minimumValue = range.lowerBound
                slider.maximumValue = range.upperBound
                slider.isContinuous = isContinuous
                if slider.value != value.wrappedValue {
                    slider.value = value.wrappedValue
                }
                configure(slider)
            },
            onEvent: { value.wrappedValue = $0.value }
        )
    }
}

/// A UIKit switch with a SwiftUI `Binding`.
@MainActor
public struct UIKitSwitch: View {
    private let isOn: Binding<Bool>
    private let configure: @MainActor (UISwitch) -> Void

    public init(
        isOn: Binding<Bool>,
        configure: @escaping @MainActor (UISwitch) -> Void = { _ in }
    ) {
        self.isOn = isOn
        self.configure = configure
    }

    public var body: some View {
        UIKitControl(
            make: UISwitch.init,
            events: .valueChanged,
            update: { control, _ in
                if control.isOn != isOn.wrappedValue {
                    control.setOn(isOn.wrappedValue, animated: false)
                }
                configure(control)
            },
            onEvent: { isOn.wrappedValue = $0.isOn }
        )
    }
}

/// A UIKit stepper with a SwiftUI `Binding`.
@MainActor
public struct UIKitStepper: View {
    private let value: Binding<Double>
    private let range: ClosedRange<Double>
    private let step: Double
    private let configure: @MainActor (UIStepper) -> Void

    public init(
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0 ... 100,
        step: Double = 1,
        configure: @escaping @MainActor (UIStepper) -> Void = { _ in }
    ) {
        self.value = value
        self.range = range
        self.step = step
        self.configure = configure
    }

    public var body: some View {
        UIKitControl(
            make: UIStepper.init,
            events: .valueChanged,
            update: { stepper, _ in
                stepper.minimumValue = range.lowerBound
                stepper.maximumValue = range.upperBound
                stepper.stepValue = step
                if stepper.value != value.wrappedValue {
                    stepper.value = value.wrappedValue
                }
                configure(stepper)
            },
            onEvent: { value.wrappedValue = $0.value }
        )
    }
}

/// A UIKit page control with a SwiftUI `Binding`.
@MainActor
public struct UIKitPageControl: View {
    private let currentPage: Binding<Int>
    private let numberOfPages: Int
    private let configure: @MainActor (UIPageControl) -> Void

    public init(
        currentPage: Binding<Int>,
        numberOfPages: Int,
        configure: @escaping @MainActor (UIPageControl) -> Void = { _ in }
    ) {
        self.currentPage = currentPage
        self.numberOfPages = numberOfPages
        self.configure = configure
    }

    public var body: some View {
        UIKitControl(
            make: UIPageControl.init,
            events: .valueChanged,
            update: { pageControl, _ in
                pageControl.numberOfPages = numberOfPages
                pageControl.currentPage = currentPage.wrappedValue
                configure(pageControl)
            },
            onEvent: { currentPage.wrappedValue = $0.currentPage }
        )
    }
}

/// A string-backed UIKit segmented control with a SwiftUI `Binding`.
@MainActor
public struct UIKitSegmentedControl: View {
    private let titles: [String]
    private let selection: Binding<Int>
    private let configure: @MainActor (UISegmentedControl) -> Void

    public init(
        _ titles: [String],
        selection: Binding<Int>,
        configure: @escaping @MainActor (UISegmentedControl) -> Void = { _ in }
    ) {
        self.titles = titles
        self.selection = selection
        self.configure = configure
    }

    public var body: some View {
        UIKitControl(
            make: { UISegmentedControl(items: titles) },
            events: .valueChanged,
            update: { segmentedControl, _ in
                synchronizeSegments(of: segmentedControl)
                segmentedControl.selectedSegmentIndex = selection.wrappedValue
                configure(segmentedControl)
            },
            onEvent: { selection.wrappedValue = $0.selectedSegmentIndex }
        )
    }

    private func synchronizeSegments(of control: UISegmentedControl) {
        let matches = control.numberOfSegments == titles.count
            && titles.indices.allSatisfy {
                control.titleForSegment(at: $0) == titles[$0]
            }
        guard !matches else { return }

        control.removeAllSegments()
        for (index, title) in titles.enumerated() {
            control.insertSegment(withTitle: title, at: index, animated: false)
        }
    }
}

/// A UIKit date picker with a SwiftUI `Binding`.
@MainActor
public struct UIKitDatePicker: View {
    private let selection: Binding<Date>
    private let range: ClosedRange<Date>?
    private let mode: UIDatePicker.Mode
    private let style: UIDatePickerStyle
    private let configure: @MainActor (UIDatePicker) -> Void

    public init(
        selection: Binding<Date>,
        in range: ClosedRange<Date>? = nil,
        displayedComponents mode: UIDatePicker.Mode = .dateAndTime,
        style: UIDatePickerStyle = .automatic,
        configure: @escaping @MainActor (UIDatePicker) -> Void = { _ in }
    ) {
        self.selection = selection
        self.range = range
        self.mode = mode
        self.style = style
        self.configure = configure
    }

    public var body: some View {
        UIKitControl(
            make: UIDatePicker.init,
            events: .valueChanged,
            update: { datePicker, _ in
                datePicker.minimumDate = range?.lowerBound
                datePicker.maximumDate = range?.upperBound
                datePicker.datePickerMode = mode
                datePicker.preferredDatePickerStyle = style
                if datePicker.date != selection.wrappedValue {
                    datePicker.setDate(selection.wrappedValue, animated: false)
                }
                configure(datePicker)
            },
            onEvent: { selection.wrappedValue = $0.date }
        )
    }
}

/// A UIKit color well with a SwiftUI `Binding`.
@MainActor
public struct UIKitColorWell: View {
    private let selection: Binding<UIColor?>
    private let supportsAlpha: Bool
    private let configure: @MainActor (UIColorWell) -> Void

    public init(
        selection: Binding<UIColor?>,
        supportsAlpha: Bool = true,
        configure: @escaping @MainActor (UIColorWell) -> Void = { _ in }
    ) {
        self.selection = selection
        self.supportsAlpha = supportsAlpha
        self.configure = configure
    }

    public var body: some View {
        UIKitControl(
            make: UIColorWell.init,
            events: .valueChanged,
            update: { colorWell, _ in
                colorWell.supportsAlpha = supportsAlpha
                if colorWell.selectedColor != selection.wrappedValue {
                    colorWell.selectedColor = selection.wrappedValue
                }
                configure(colorWell)
            },
            onEvent: { selection.wrappedValue = $0.selectedColor }
        )
    }
}

/// A configuration-based UIKit button.
@MainActor
public struct UIKitButton: View {
    private let configuration: UIButton.Configuration
    private let configure: @MainActor (UIButton) -> Void
    private let action: @MainActor () -> Void

    public init(
        configuration: UIButton.Configuration,
        configure: @escaping @MainActor (UIButton) -> Void = { _ in },
        action: @escaping @MainActor () -> Void
    ) {
        self.configuration = configuration
        self.configure = configure
        self.action = action
    }

    public init(
        _ title: String,
        configure: @escaping @MainActor (UIButton) -> Void = { _ in },
        action: @escaping @MainActor () -> Void
    ) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        self.init(
            configuration: configuration,
            configure: configure,
            action: action
        )
    }

    public var body: some View {
        UIKitControl(
            make: { UIButton(configuration: configuration) },
            events: .primaryActionTriggered,
            update: { button, _ in
                button.configuration = configuration
                configure(button)
            },
            onEvent: { _ in action() }
        )
    }
}

