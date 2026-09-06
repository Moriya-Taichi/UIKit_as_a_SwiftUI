#if os(macOS)
import AppKit
import SwiftUI

@MainActor
public struct AppKitButton: View, AppKitViewConfiguring {
    public typealias AppKitViewType = NSButton
    @Environment(\.locale) private var locale
    private let title: AppKitDisplayText
    private let action: @MainActor () -> Void
    private var configure: @MainActor (NSButton) -> Void = { _ in }

    public init(_ title: LocalizedStringResource, action: @escaping @MainActor () -> Void) {
        self.title = .localized(title)
        self.action = action
    }

    public init(verbatim title: String, action: @escaping @MainActor () -> Void) {
        self.title = .verbatim(title)
        self.action = action
    }

    public var body: some View {
        AppKitControl(make: { NSButton(title: "", target: nil, action: nil) }, update: { button, _ in
            configure(button)
            button.title = title.resolve(in: locale)
        }, onEvent: { _ in action() })
    }
}

@MainActor
public struct AppKitToggle: View, AppKitViewConfiguring {
    public typealias AppKitViewType = NSButton
    @Environment(\.locale) private var locale
    @Binding private var isOn: Bool
    private let title: AppKitDisplayText
    private var configure: @MainActor (NSButton) -> Void = { _ in }

    public init(_ title: LocalizedStringResource, isOn: Binding<Bool>) {
        self.title = .localized(title)
        _isOn = isOn
    }

    public init(verbatim title: String, isOn: Binding<Bool>) {
        self.title = .verbatim(title)
        _isOn = isOn
    }

    public var body: some View {
        AppKitControl(make: { NSButton(checkboxWithTitle: "", target: nil, action: nil) }, update: { button, _ in
            configure(button)
            button.title = title.resolve(in: locale)
            button.state = isOn ? .on : .off
        }, onEvent: { isOn = $0.state == .on })
    }
}

@MainActor
public struct AppKitSwitch: View, AppKitViewConfiguring {
    public typealias AppKitViewType = NSSwitch
    @Binding private var isOn: Bool
    private var configure: @MainActor (NSSwitch) -> Void = { _ in }

    public init(isOn: Binding<Bool>) { _isOn = isOn }

    public var body: some View {
        AppKitControl(make: { NSSwitch() }, update: { control, _ in
            configure(control)
            control.state = isOn ? .on : .off
        }, onEvent: { isOn = $0.state == .on })
    }
}

@MainActor
public struct AppKitSlider<Value: BinaryFloatingPoint>: View, AppKitViewConfiguring {
    public typealias AppKitViewType = NSSlider
    @Binding private var value: Value
    private let bounds: ClosedRange<Value>
    private var configure: @MainActor (NSSlider) -> Void = { _ in }

    public init(value: Binding<Value>, in bounds: ClosedRange<Value> = 0...1) {
        precondition(Double(bounds.lowerBound).isFinite && Double(bounds.upperBound).isFinite)
        _value = value
        self.bounds = bounds
    }

    public var body: some View {
        AppKitControl(make: { NSSlider() }, update: { slider, _ in
            configure(slider)
            slider.minValue = Double(bounds.lowerBound)
            slider.maxValue = Double(bounds.upperBound)
            slider.doubleValue = Double(value)
        }, onEvent: { value = Value($0.doubleValue) })
    }
}

@MainActor
public struct AppKitStepper: View, AppKitViewConfiguring {
    public typealias AppKitViewType = NSStepper
    @Binding private var value: Double
    private let bounds: ClosedRange<Double>
    private let step: Double
    private var configure: @MainActor (NSStepper) -> Void = { _ in }

    public init(value: Binding<Double>, in bounds: ClosedRange<Double> = 0...100, step: Double = 1) {
        precondition(bounds.lowerBound.isFinite && bounds.upperBound.isFinite && step.isFinite && step > 0)
        _value = value
        self.bounds = bounds
        self.step = step
    }

    public init(value: Binding<Int>, in bounds: ClosedRange<Int> = 0...100, step: Int = 1) {
        precondition(step > 0)
        self.init(value: Binding(get: { Double(value.wrappedValue) }, set: { newValue, transaction in
            if let integer = Int(exactly: newValue) { value.transaction(transaction).wrappedValue = integer }
        }), in: Double(bounds.lowerBound)...Double(bounds.upperBound), step: Double(step))
    }

    public var body: some View {
        AppKitControl(make: { NSStepper() }, update: { stepper, _ in
            configure(stepper)
            stepper.minValue = bounds.lowerBound
            stepper.maxValue = bounds.upperBound
            stepper.increment = step
            stepper.doubleValue = value
        }, onEvent: { value = $0.doubleValue })
    }
}

@MainActor
public struct AppKitSegmentedControl<SelectionValue: Hashable>: View, AppKitViewConfiguring {
    public typealias AppKitViewType = NSSegmentedControl
    @Environment(\.locale) private var locale
    private let values: [SelectionValue]
    @Binding private var selection: SelectionValue?
    private let titles: [AppKitDisplayText]
    private var configure: @MainActor (NSSegmentedControl) -> Void = { _ in }

    public init(_ values: [SelectionValue], selection: Binding<SelectionValue?>, title: (SelectionValue) -> String) {
        precondition(Set(values).count == values.count, "Segment values must be unique")
        self.values = values
        _selection = selection
        titles = values.map { .verbatim(title($0)) }
    }

    public init(_ values: [SelectionValue], selection: Binding<SelectionValue>, title: (SelectionValue) -> String) {
        self.init(values, selection: Binding(get: { selection.wrappedValue }, set: { value, transaction in
            if let value { selection.transaction(transaction).wrappedValue = value }
        }), title: title)
    }

    public init(_ values: [SelectionValue], selection: Binding<SelectionValue?>, localizedTitle: (SelectionValue) -> LocalizedStringResource) {
        precondition(Set(values).count == values.count, "Segment values must be unique")
        self.values = values
        _selection = selection
        titles = values.map { .localized(localizedTitle($0)) }
    }

    public init(_ values: [SelectionValue], selection: Binding<SelectionValue>, localizedTitle: (SelectionValue) -> LocalizedStringResource) {
        self.init(values, selection: Binding(get: { selection.wrappedValue }, set: { value, transaction in
            if let value { selection.transaction(transaction).wrappedValue = value }
        }), localizedTitle: localizedTitle)
    }

    public var body: some View {
        AppKitControl(make: { NSSegmentedControl() }, update: { control, _ in
            configure(control)
            control.trackingMode = .selectOne
            control.segmentCount = values.count
            for index in values.indices { control.setLabel(titles[index].resolve(in: locale), forSegment: index) }
            control.selectedSegment = selection.flatMap { values.firstIndex(of: $0) } ?? -1
        }, onEvent: { control in
            selection = values.indices.contains(control.selectedSegment) ? values[control.selectedSegment] : nil
        })
    }
}

@MainActor
public struct AppKitDatePicker: View, AppKitViewConfiguring {
    public typealias AppKitViewType = NSDatePicker
    @Environment(\.locale) private var locale
    @Binding private var selection: Date
    private let title: AppKitDisplayText
    private let components: DatePickerComponents
    private let bounds: ClosedRange<Date>?
    private var configure: @MainActor (NSDatePicker) -> Void = { _ in }

    public init(_ title: LocalizedStringResource, selection: Binding<Date>, in bounds: ClosedRange<Date>? = nil,
                displayedComponents: DatePickerComponents = [.date, .hourAndMinute]) {
        precondition(!displayedComponents.isEmpty)
        self.title = .localized(title)
        _selection = selection
        components = displayedComponents
        self.bounds = bounds
    }

    public init(verbatim title: String, selection: Binding<Date>, in bounds: ClosedRange<Date>? = nil,
                displayedComponents: DatePickerComponents = [.date, .hourAndMinute]) {
        precondition(!displayedComponents.isEmpty)
        self.title = .verbatim(title)
        _selection = selection
        components = displayedComponents
        self.bounds = bounds
    }

    public var body: some View {
        LabeledContent {
            AppKitControl(make: { NSDatePicker() }, update: { picker, context in
                configure(picker)
                var elements: NSDatePicker.ElementFlags = []
                if components.contains(.date) { elements.insert(.yearMonthDay) }
                if components.contains(.hourAndMinute) { elements.insert(.hourMinute) }
                picker.datePickerElements = elements
                picker.locale = context.environment.locale
                picker.calendar = context.environment.calendar
                picker.timeZone = context.environment.timeZone
                picker.minDate = bounds?.lowerBound
                picker.maxDate = bounds?.upperBound
                picker.dateValue = selection
            }, onEvent: { selection = $0.dateValue })
        } label: {
            Text(verbatim: title.resolve(in: locale))
        }
    }
}
public extension AppKitButton {
    func configureAppKit(_ body: @escaping @MainActor (NSButton) -> Void) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { view in
            previous(view)
            body(view)
        }
        return copy
    }
}
public extension AppKitToggle {
    func configureAppKit(_ body: @escaping @MainActor (NSButton) -> Void) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { view in
            previous(view)
            body(view)
        }
        return copy
    }
}
public extension AppKitSwitch {
    func configureAppKit(_ body: @escaping @MainActor (NSSwitch) -> Void) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { view in
            previous(view)
            body(view)
        }
        return copy
    }
}
public extension AppKitSlider {
    func configureAppKit(_ body: @escaping @MainActor (NSSlider) -> Void) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { view in
            previous(view)
            body(view)
        }
        return copy
    }
}
public extension AppKitStepper {
    func configureAppKit(_ body: @escaping @MainActor (NSStepper) -> Void) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { view in
            previous(view)
            body(view)
        }
        return copy
    }
}
public extension AppKitSegmentedControl {
    func configureAppKit(_ body: @escaping @MainActor (NSSegmentedControl) -> Void) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { view in
            previous(view)
            body(view)
        }
        return copy
    }
}
public extension AppKitDatePicker {
    func configureAppKit(_ body: @escaping @MainActor (NSDatePicker) -> Void) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { view in
            previous(view)
            body(view)
        }
        return copy
    }
}
#endif
