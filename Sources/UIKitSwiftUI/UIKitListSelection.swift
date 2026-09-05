import SwiftUI
import UIKit

@MainActor
enum UIKitListSelection<ID: Hashable> {
    /// The legacy model/delegate API owns selection behavior.
    case unmanaged
    case none
    case single(Binding<ID?>)
    case multiple(Binding<Set<ID>>)

    var ids: Set<ID>? {
        switch self {
        case .unmanaged: return nil
        case .none: return []
        case .single(let binding):
            return binding.wrappedValue.map { [$0] } ?? []
        case .multiple(let binding): return binding.wrappedValue
        }
    }

    var allowsSelection: Bool? {
        switch self {
        case .unmanaged: return nil
        case .none: return false
        case .single, .multiple: return true
        }
    }

    var allowsMultipleSelection: Bool? {
        switch self {
        case .unmanaged: return nil
        case .none, .single: return false
        case .multiple: return true
        }
    }

    func select(_ id: ID) {
        switch self {
        case .single(let binding):
            if binding.wrappedValue != id { binding.wrappedValue = id }
        case .multiple(let binding):
            if !binding.wrappedValue.contains(id) {
                binding.wrappedValue.insert(id)
            }
        case .none, .unmanaged: break
        }
    }

    func deselect(_ id: ID) {
        switch self {
        case .single(let binding):
            if binding.wrappedValue == id { binding.wrappedValue = nil }
        case .multiple(let binding):
            if binding.wrappedValue.contains(id) {
                binding.wrappedValue.remove(id)
            }
        case .none, .unmanaged: break
        }
    }
}

/// A snapshot of the caller's values, indexed by stable identity. Elements need
/// neither `Hashable` nor `Sendable`; only diffable identifiers do.
@MainActor
struct UIKitIdentifiedData<Element, ID: Hashable & Sendable> {
    let snapshot: NSDiffableDataSourceSnapshot<Int, ID>
    let elements: [ID: Element]

    init<Data: Collection>(_ data: Data, id: KeyPath<Element, ID>) where Data.Element == Element {
        var identifiers: [ID] = []
        var elements: [ID: Element] = [:]
        var seen: Set<ID> = []
        for element in data {
            let identifier = element[keyPath: id]
            precondition(seen.insert(identifier).inserted, "List item IDs must be unique.")
            identifiers.append(identifier)
            elements[identifier] = element
        }
        var snapshot = NSDiffableDataSourceSnapshot<Int, ID>()
        snapshot.appendSections([0])
        snapshot.appendItems(identifiers, toSection: 0)
        self.snapshot = snapshot
        self.elements = elements
    }
}
