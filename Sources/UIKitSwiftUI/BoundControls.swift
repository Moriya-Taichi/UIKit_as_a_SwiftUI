#if canImport(UIKit)
import SwiftUI
import UIKit

/// A UIKit slider with a SwiftUI `Binding`.
@MainActor
public struct UIKitSlider: View {
    private let value: Binding<Float>
    private let range: ClosedRange<Float>
    private let isContinuous: Bool
    private var configure: @MainActor (UISlider) -> Void

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
    private var configure: @MainActor (UISwitch) -> Void

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
    private var configure: @MainActor (UIStepper) -> Void

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
    private var configure: @MainActor (UIPageControl) -> Void

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
    @Environment(\.locale) private var locale
    private var titles: [UIKitDisplayText]
    private let selection: Binding<Int>
    private var configure: @MainActor (UISegmentedControl) -> Void

    public init(
        _ titles: [String],
        selection: Binding<Int>,
        configure: @escaping @MainActor (UISegmentedControl) -> Void = { _ in }
    ) {
        self.titles = titles.map(UIKitDisplayText.verbatim)
        self.selection = selection
        self.configure = configure
    }

    public var body: some View {
        let titles = self.titles.map { $0.resolve(in: locale) }
        return UIKitControl(
            make: { UISegmentedControl(items: titles) },
            events: .valueChanged,
            update: { segmentedControl, _ in
                synchronizeSegments(of: segmentedControl, titles: titles)
                segmentedControl.selectedSegmentIndex = selection.wrappedValue
                configure(segmentedControl)
            },
            onEvent: { selection.wrappedValue = $0.selectedSegmentIndex }
        )
    }

    private func synchronizeSegments(of control: UISegmentedControl, titles: [String]) {
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
    @Environment(\.locale) private var locale
    private var title: UIKitDisplayText?
    private let selection: Binding<Date>
    private let range: ClosedRange<Date>?
    private let mode: UIDatePicker.Mode
    private let style: UIDatePickerStyle
    private var configure: @MainActor (UIDatePicker) -> Void

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
        if let title {
            LabeledContent {
                control
            } label: {
                Text(verbatim: title.resolve(in: locale))
            }
        } else {
            control
        }
    }

    private var control: some View {
        UIKitControl(
            make: UIDatePicker.init,
            events: .valueChanged,
            update: { datePicker, context in
                datePicker.locale = context.environment.locale
                datePicker.calendar = context.environment.calendar
                datePicker.timeZone = context.environment.timeZone
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
    private var configure: @MainActor (UIColorWell) -> Void

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
    @Environment(\.locale) private var locale
    private var title: UIKitDisplayText?
    private let configuration: UIButton.Configuration
    private var configure: @MainActor (UIButton) -> Void
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
        var configuration = self.configuration
        if let title {
            configuration.title = title.resolve(in: locale)
        }
        return UIKitControl(
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


extension UIKitSlider: UIKitViewConfiguring {
    public typealias UIKitViewType = UISlider

    /// Appends UIKit configuration to each update.
    public func configureUIKit(
        _ body: @escaping @MainActor (UISlider) -> Void
    ) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { view in
            previous(view)
            body(view)
        }
        return copy
    }
}

extension UIKitSwitch: UIKitViewConfiguring {
    public typealias UIKitViewType = UISwitch

    /// Appends UIKit configuration to each update.
    public func configureUIKit(
        _ body: @escaping @MainActor (UISwitch) -> Void
    ) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { view in
            previous(view)
            body(view)
        }
        return copy
    }
}

extension UIKitStepper: UIKitViewConfiguring {
    public typealias UIKitViewType = UIStepper

    /// Appends UIKit configuration to each update.
    public func configureUIKit(
        _ body: @escaping @MainActor (UIStepper) -> Void
    ) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { view in
            previous(view)
            body(view)
        }
        return copy
    }
}

extension UIKitPageControl: UIKitViewConfiguring {
    public typealias UIKitViewType = UIPageControl

    /// Appends UIKit configuration to each update.
    public func configureUIKit(
        _ body: @escaping @MainActor (UIPageControl) -> Void
    ) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { view in
            previous(view)
            body(view)
        }
        return copy
    }
}

extension UIKitSegmentedControl: UIKitViewConfiguring {
    public typealias UIKitViewType = UISegmentedControl

    /// Appends UIKit configuration to each update.
    public func configureUIKit(
        _ body: @escaping @MainActor (UISegmentedControl) -> Void
    ) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { view in
            previous(view)
            body(view)
        }
        return copy
    }
}

extension UIKitDatePicker: UIKitViewConfiguring {
    public typealias UIKitViewType = UIDatePicker

    /// Appends UIKit configuration to each update.
    public func configureUIKit(
        _ body: @escaping @MainActor (UIDatePicker) -> Void
    ) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { view in
            previous(view)
            body(view)
        }
        return copy
    }
}

extension UIKitColorWell: UIKitViewConfiguring {
    public typealias UIKitViewType = UIColorWell

    /// Appends UIKit configuration to each update.
    public func configureUIKit(
        _ body: @escaping @MainActor (UIColorWell) -> Void
    ) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { view in
            previous(view)
            body(view)
        }
        return copy
    }
}

extension UIKitButton: UIKitViewConfiguring {
    public typealias UIKitViewType = UIButton

    /// Appends UIKit configuration to each update.
    public func configureUIKit(
        _ body: @escaping @MainActor (UIButton) -> Void
    ) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { view in
            previous(view)
            body(view)
        }
        return copy
    }
}

public extension UIKitSlider {
    /// Creates a slider for a floating-point binding, including `Double`.
    ///
    /// UIKit represents the range and user edits as `Float`. Displaying a value
    /// never writes its rounded representation back to the source binding.
    init<Value: BinaryFloatingPoint>(
        value: Binding<Value>,
        in range: ClosedRange<Value> = 0 ... 1,
        isContinuous: Bool = true,
        configure: @escaping @MainActor (UISlider) -> Void = { _ in }
    ) {
        let lower = Float(range.lowerBound)
        let upper = Float(range.upperBound)
        precondition(lower.isFinite && upper.isFinite, "UISlider requires a finite Float range.")
        self.init(
            value: Binding<Float>(
                get: { Float(value.wrappedValue) },
                set: { newValue, transaction in
                    value.transaction(transaction).wrappedValue = Value(newValue)
                }
            ),
            in: lower ... upper,
            isContinuous: isContinuous,
            configure: configure
        )
    }
}

public extension UIKitSegmentedControl {
    /// Creates segments identified by values rather than their display indices.
    /// Values must be unique. A selection absent from the data displays no segment.
    init<SelectionValue: Hashable>(
        _ values: [SelectionValue],
        selection: Binding<SelectionValue>,
        title: (SelectionValue) -> String
    ) {
        precondition(Set(values).count == values.count, "Segment values must be unique.")
        self.init(
            values.map(title),
            selection: Binding(
                get: { values.firstIndex(of: selection.wrappedValue) ?? UISegmentedControl.noSegment },
                set: { index, transaction in
                    guard values.indices.contains(index) else { return }
                    selection.transaction(transaction).wrappedValue = values[index]
                }
            )
        )
    }

    /// Creates value-identified segments with an optional selection.
    init<SelectionValue: Hashable>(
        _ values: [SelectionValue],
        selection: Binding<SelectionValue?>,
        title: (SelectionValue) -> String
    ) {
        precondition(Set(values).count == values.count, "Segment values must be unique.")
        self.init(
            values.map(title),
            selection: Binding(
                get: {
                    guard let value = selection.wrappedValue else { return UISegmentedControl.noSegment }
                    return values.firstIndex(of: value) ?? UISegmentedControl.noSegment
                },
                set: { index, transaction in
                    if index == UISegmentedControl.noSegment {
                        selection.transaction(transaction).wrappedValue = nil
                    } else if values.indices.contains(index) {
                        selection.transaction(transaction).wrappedValue = values[index]
                    }
                }
            )
        )
    }

    /// Creates value-identified segments with titles localized in the environment locale.
    init<SelectionValue: Hashable>(
        _ values: [SelectionValue],
        selection: Binding<SelectionValue>,
        localizedTitle: (SelectionValue) -> LocalizedStringResource
    ) {
        self.init(values, selection: selection, title: { _ in "" })
        titles = values.map { .localized(localizedTitle($0)) }
    }

    /// Creates localized segments with an optional, value-based selection.
    init<SelectionValue: Hashable>(
        _ values: [SelectionValue],
        selection: Binding<SelectionValue?>,
        localizedTitle: (SelectionValue) -> LocalizedStringResource
    ) {
        self.init(values, selection: selection, title: { _ in "" })
        titles = values.map { .localized(localizedTitle($0)) }
    }
}

public extension UIKitDatePicker {
    /// Creates a labeled date picker using SwiftUI's component vocabulary.
    init(
        _ title: LocalizedStringResource,
        selection: Binding<Date>,
        in range: ClosedRange<Date>? = nil,
        displayedComponents: DatePickerComponents = [.date, .hourAndMinute],
        style: UIDatePickerStyle = .automatic,
        configure: @escaping @MainActor (UIDatePicker) -> Void = { _ in }
    ) {
        self.init(
            selection: selection, in: range, mode: Self.mode(for: displayedComponents),
            style: style, configure: configure
        )
        self.title = .localized(title)
    }

    /// Creates a labeled date picker without localizing its title.
    init(
        verbatim title: String,
        selection: Binding<Date>,
        in range: ClosedRange<Date>? = nil,
        displayedComponents: DatePickerComponents = [.date, .hourAndMinute],
        style: UIDatePickerStyle = .automatic,
        configure: @escaping @MainActor (UIDatePicker) -> Void = { _ in }
    ) {
        self.init(
            selection: selection, in: range, mode: Self.mode(for: displayedComponents),
            style: style, configure: configure
        )
        self.title = .verbatim(title)
    }

    /// Creates an unlabeled picker with a UIKit-specific mode.
    init(
        selection: Binding<Date>,
        in range: ClosedRange<Date>? = nil,
        mode: UIDatePicker.Mode,
        style: UIDatePickerStyle = .automatic,
        configure: @escaping @MainActor (UIDatePicker) -> Void = { _ in }
    ) {
        self.init(
            selection: selection, in: range, displayedComponents: mode,
            style: style, configure: configure
        )
    }

    private static func mode(for components: DatePickerComponents) -> UIDatePicker.Mode {
        precondition(!components.isEmpty, "A date picker needs at least one displayed component.")
        if components == .date { return .date }
        if components == .hourAndMinute { return .time }
        return .dateAndTime
    }
}

public extension UIKitButton {
    /// Creates a button whose title follows SwiftUI's environment locale.
    init(
        localized title: LocalizedStringResource,
        configure: @escaping @MainActor (UIButton) -> Void = { _ in },
        action: @escaping @MainActor () -> Void
    ) {
        self.init("", configure: configure, action: action)
        self.title = .localized(title)
    }

    /// Creates a button with a title displayed without localization.
    init(
        verbatim title: String,
        configure: @escaping @MainActor (UIButton) -> Void = { _ in },
        action: @escaping @MainActor () -> Void
    ) {
        self.init(title, configure: configure, action: action)
    }
}
#endif
