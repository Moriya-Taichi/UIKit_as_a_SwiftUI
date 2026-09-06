#if os(macOS)
import AppKit
import SwiftUI

@MainActor
private struct AppKitListRow<ID: Hashable, Content: View>: View {
    let id: ID
    let content: Content
    let environment: EnvironmentValues

    var body: some View { content.id(id).environment(\.self, environment) }
}

@MainActor
final class AppKitListStorage<ID: Hashable, Content: View> {
    private var hosts: [ID: NSHostingView<AppKitListRow<ID, Content>>] = [:]
    var ids: [ID] = []
    var content: (ID) -> Content
    var environment: EnvironmentValues

    init(content: @escaping (ID) -> Content, environment: EnvironmentValues) {
        self.content = content
        self.environment = environment
    }

    func update(ids: [ID], content: @escaping (ID) -> Content, environment: EnvironmentValues) {
        self.ids = ids
        self.content = content
        self.environment = environment
        let retained = Set(ids)
        hosts = hosts.filter { retained.contains($0.key) }
        for (id, host) in hosts {
            host.rootView = AppKitListRow(id: id, content: content(id), environment: environment)
        }
    }

    func view(at index: Int) -> NSView? {
        guard ids.indices.contains(index) else { return nil }
        let id = ids[index]
        if let host = hosts[id] { return host }
        let host = NSHostingView(rootView: AppKitListRow(id: id, content: content(id), environment: environment))
        hosts[id] = host
        return host
    }
}

@MainActor
struct AppKitListData<ID: Hashable, Content: View> {
    let ids: [ID]
    let content: (ID) -> Content

    init<Data: RandomAccessCollection>(_ data: Data, id: KeyPath<Data.Element, ID>, content: @escaping (Data.Element) -> Content) {
        var elements: [ID: Data.Element] = [:]
        var ids: [ID] = []
        for element in data {
            let identifier = element[keyPath: id]
            precondition(elements.updateValue(element, forKey: identifier) == nil, "List IDs must be unique")
            ids.append(identifier)
        }
        self.ids = ids
        self.content = { identifier in
            guard let element = elements[identifier] else { preconditionFailure("Unknown list ID") }
            return content(element)
        }
    }
}

@MainActor
enum AppKitListSelection<ID: Hashable> {
    case none
    case single(Binding<ID?>)
    case multiple(Binding<Set<ID>>)

    var ids: Set<ID> {
        switch self {
        case .none: []
        case .single(let binding): binding.wrappedValue.map { [$0] } ?? []
        case .multiple(let binding): binding.wrappedValue
        }
    }

    var allowsSelection: Bool {
        if case .none = self { return false }
        return true
    }

    var allowsMultiple: Bool {
        if case .multiple = self { return true }
        return false
    }

    func setVisibleSelection(_ selected: Set<ID>, visibleIDs: Set<ID>) {
        switch self {
        case .none: break
        case .single(let binding):
            // A user action replaces a single selection, including a hidden selection.
            if binding.wrappedValue != selected.first { binding.wrappedValue = selected.first }
        case .multiple(let binding):
            let updated = binding.wrappedValue.subtracting(visibleIDs).union(selected)
            if binding.wrappedValue != updated { binding.wrappedValue = updated }
        }
    }
}
#endif
