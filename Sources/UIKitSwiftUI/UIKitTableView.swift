import SwiftUI
import UIKit

/// The reuse identifier of the plain cell the bridge always registers.
private let tableViewCellReuseIdentifier = "UIKitSwiftUI.UIKitTableView.Cell"

/// A UIKit table view whose data comes from an observable `UIKitListModel`.
///
/// The model owns the sections, the items, and the selection; the bridge owns
/// a `UITableViewDiffableDataSource` built from the model's snapshot. Callers
/// never implement `UITableViewDataSource`: they only describe how an item
/// becomes a cell.
@available(iOS 17.0, macCatalyst 17.0, *)
@MainActor
public struct UIKitTableView<
    SectionID: Hashable & Sendable,
    Item: Hashable & Sendable
>: UIViewRepresentable {
    public typealias UIViewType = UITableView

    /// Builds the cell for an item, like a diffable data source cell provider.
    public typealias CellProvider = @MainActor (
        UITableView,
        IndexPath,
        Item
    ) -> UITableViewCell

    private let model: UIKitListModel<SectionID, Item>?
    // Built while SwiftUI evaluates the caller's body so reading `sections`
    // establishes the observation dependency that recreates this value.
    private let snapshot: NSDiffableDataSourceSnapshot<SectionID, Item>
    private let style: UITableView.Style
    private let animatesDifferences: Bool
    private var configure: @MainActor (UITableView) -> Void
    fileprivate typealias ContextualCellProvider = @MainActor (
        UITableView, IndexPath, Item, EnvironmentValues
    ) -> UITableViewCell

    private let cell: ContextualCellProvider
    private var selection: UIKitListSelection<Item> = .unmanaged
    private var selectedIDs: Set<Item>?

    /// Creates a table view that builds its cells with the given provider.
    ///
    /// The provider is refreshed on every update, so it may capture current
    /// SwiftUI state. Every visible cell is reconfigured on each update, so
    /// the state the provider captures stays current even when the items
    /// themselves are unchanged.
    public init(
        model: UIKitListModel<SectionID, Item>,
        style: UITableView.Style = .plain,
        animatesDifferences: Bool = true,
        configure: @escaping @MainActor (UITableView) -> Void = { _ in },
        cell: @escaping CellProvider
    ) {
        self.model = model
        snapshot = model.snapshot()
        self.style = style
        self.animatesDifferences = animatesDifferences
        self.configure = configure
        self.cell = { table, indexPath, item, _ in cell(table, indexPath, item) }
    }

    /// Creates a table view whose cells are plain list-content cells.
    ///
    /// The bridge registers a `UITableViewCell` under a private reuse
    /// identifier and applies the configuration the closure returns. Every
    /// visible cell is reconfigured on each update, so the state the closure
    /// captures stays current even when the items themselves are unchanged.
    public init(
        model: UIKitListModel<SectionID, Item>,
        style: UITableView.Style = .plain,
        animatesDifferences: Bool = true,
        configure: @escaping @MainActor (UITableView) -> Void = { _ in },
        content: @escaping @MainActor (Item) -> UIListContentConfiguration
    ) {
        self.init(
            model: model,
            style: style,
            animatesDifferences: animatesDifferences,
            configure: configure,
            cell: { tableView, indexPath, item in
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: tableViewCellReuseIdentifier,
                    for: indexPath
                )
                cell.contentConfiguration = content(item)
                return cell
            }
        )
    }

    /// Keeps the diffable data source and forwards selection to the model.
    @MainActor
    public final class Coordinator: NSObject, UITableViewDelegate {
        fileprivate var model: UIKitListModel<SectionID, Item>?
        fileprivate let environment = UIKitEnvironmentState()
        fileprivate var environmentValues = EnvironmentValues()
        fileprivate var selection: UIKitListSelection<Item> = .unmanaged
        fileprivate var selectedIDs: Set<Item>?
        fileprivate var cellProvider: ContextualCellProvider
        fileprivate var dataSource:
            UITableViewDiffableDataSource<SectionID, Item>?

        fileprivate init(
            model: UIKitListModel<SectionID, Item>?,
            cellProvider: @escaping ContextualCellProvider
        ) {
            self.model = model
            self.cellProvider = cellProvider
        }

        public func tableView(
            _ tableView: UITableView,
            didSelectRowAt indexPath: IndexPath
        ) {
            guard let item = dataSource?.itemIdentifier(for: indexPath) else {
                return
            }
            model?.handleSelected(item)
            selection.select(item)
            selectedIDs = selection.ids
        }

        public func tableView(
            _ tableView: UITableView,
            didDeselectRowAt indexPath: IndexPath
        ) {
            guard let item = dataSource?.itemIdentifier(for: indexPath) else {
                return
            }
            model?.handleDeselected(item)
            selection.deselect(item)
            selectedIDs = selection.ids
        }

        fileprivate func configureSelection(_ tableView: UITableView) {
            if let allowsSelection = selection.allowsSelection {
                tableView.allowsSelection = allowsSelection
            }
            if let multiple = selection.allowsMultipleSelection {
                tableView.allowsMultipleSelection = multiple
            }
        }

        fileprivate func synchronizeSelection(_ tableView: UITableView) {
            guard let selectedIDs, let dataSource else { return }
            let desired = Set(selectedIDs.compactMap { dataSource.indexPath(for: $0) })
            let current = Set(tableView.indexPathsForSelectedRows ?? [])
            for indexPath in current.subtracting(desired) {
                tableView.deselectRow(at: indexPath, animated: false)
            }
            for indexPath in desired.subtracting(current) {
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(model: model, cellProvider: cell)
    }

    public func makeUIView(context: Context) -> UITableView {
        let tableView = UITableView(frame: .zero, style: style)
        tableView.register(
            UITableViewCell.self,
            forCellReuseIdentifier: tableViewCellReuseIdentifier
        )

        let coordinator = context.coordinator
        coordinator.model = model
        coordinator.cellProvider = cell
        coordinator.environmentValues = context.environment
        coordinator.selection = selection
        coordinator.selectedIDs = selectedIDs

        // The SDK's cell provider is not actor-annotated on every supported
        // SDK, and the data source only calls it on the main actor. The cell
        // leaves the assumption through a `nonisolated(unsafe)` local because
        // `assumeIsolated` constrains its own result type on some toolchains.
        let dataSource = UITableViewDiffableDataSource<SectionID, Item>(
            tableView: tableView
        ) { [weak coordinator] tableView, indexPath, item in
            nonisolated(unsafe) var cell: UITableViewCell? = nil
            MainActor.assumeIsolated {
                if let coordinator {
                    cell = coordinator.cellProvider(tableView, indexPath, item, coordinator.environmentValues)
                }
            }
            return cell
        }
        coordinator.dataSource = dataSource

        coordinator.environment.update(tableView, environment: context.environment, configure: configure)
        tableView.delegate = coordinator
        tableView.dataSource = dataSource
        coordinator.configureSelection(tableView)
        dataSource.apply(snapshot, animatingDifferences: false) { [weak coordinator, weak tableView] in
            MainActor.assumeIsolated {
                if let tableView { coordinator?.synchronizeSelection(tableView) }
            }
        }
        return tableView
    }

    public func updateUIView(_ uiView: UITableView, context: Context) {
        let coordinator = context.coordinator
        coordinator.model = model
        coordinator.cellProvider = cell
        coordinator.environmentValues = context.environment
        coordinator.selection = selection
        coordinator.selectedIDs = selectedIDs
        coordinator.environment.update(uiView, environment: context.environment, configure: configure)
        coordinator.configureSelection(uiView)
        if uiView.delegate !== coordinator {
            uiView.delegate = coordinator
        }

        guard let dataSource = coordinator.dataSource else { return }
        uiView.dataSource = dataSource
        dataSource.apply(
            Self.updateSnapshot(
                current: dataSource.snapshot(),
                updated: snapshot
            ),
            animatingDifferences: animatesDifferences && !context.transaction.disablesAnimations
        ) { [weak coordinator, weak uiView] in
            MainActor.assumeIsolated {
                if let uiView { coordinator?.synchronizeSelection(uiView) }
            }
        }
    }

    public static func dismantleUIView(
        _ uiView: UITableView,
        coordinator: Coordinator
    ) {
        if uiView.delegate === coordinator {
            uiView.delegate = nil
        }
        coordinator.environment.dismantle()
        if uiView.dataSource === coordinator.dataSource {
            uiView.dataSource = nil
        }
        coordinator.dataSource = nil
        coordinator.model = nil
    }

    /// The snapshot to apply for `updated`, with every item that persists
    /// from `current` marked for reconfiguration.
    ///
    /// An update whose identifiers are unchanged still has to re-run the cell
    /// path, because the provider captures SwiftUI state that may have moved
    /// on. Reconfiguration re-invokes the provider for the item's existing
    /// cell instead of replacing the cell, so the diff stays a no-op while
    /// the content refreshes.
    static func updateSnapshot(
        current: NSDiffableDataSourceSnapshot<SectionID, Item>,
        updated: NSDiffableDataSourceSnapshot<SectionID, Item>
    ) -> NSDiffableDataSourceSnapshot<SectionID, Item> {
        var result = updated
        let currentItems = Set(current.itemIdentifiers)
        let persisting = result.itemIdentifiers.filter(currentItems.contains)
        if !persisting.isEmpty {
            result.reconfigureItems(persisting)
        }
        return result
    }
}

@available(iOS 17.0, macCatalyst 17.0, *)
extension UIKitTableView: UIKitViewConfiguring {
    public typealias UIKitViewType = UITableView

    /// Appends UIKit configuration to each update.
    public func configureUIKit(_ body: @escaping @MainActor (UITableView) -> Void) -> Self {
        var copy = self
        let previous = configure
        copy.configure = { view in
            previous(view)
            body(view)
        }
        return copy
    }
}

@available(iOS 17.0, macCatalyst 17.0, *)
extension UIKitTableView where SectionID == Int {
    private init<Element, Content: View>(
        identified data: UIKitIdentifiedData<Element, Item>,
        selection: UIKitListSelection<Item>,
        style: UITableView.Style,
        animatesDifferences: Bool,
        @ViewBuilder content: @escaping @MainActor (Element) -> Content
    ) {
        model = nil
        snapshot = data.snapshot
        self.selection = selection
        // Read while evaluating the caller's body so Binding/Observation
        // changes participate in SwiftUI's dependency tracking.
        selectedIDs = selection.ids
        self.style = style
        self.animatesDifferences = animatesDifferences
        configure = { _ in }
        cell = { table, indexPath, id, environment in
            let cell = table.dequeueReusableCell(
                withIdentifier: tableViewCellReuseIdentifier, for: indexPath
            )
            if let element = data.elements[id] {
                cell.contentConfiguration = UIHostingConfiguration {
                    content(element).id(id).environment(\.self, environment)
                }
            } else {
                cell.contentConfiguration = nil
            }
            return cell
        }
    }
}

@available(iOS 17.0, macCatalyst 17.0, *)
public extension UIKitTableView where SectionID == Int {

    /// Creates SwiftUI rows with stable IDs and optional single selection.
    ///
    /// IDs must be unique. The binding may retain IDs absent from the data;
    /// only present IDs are selected, so filtering does not discard selection.
    init<Data: RandomAccessCollection, Content: View>(
        _ data: Data,
        id: KeyPath<Data.Element, Item>,
        selection: Binding<Item?>? = nil,
        style: UITableView.Style = .plain,
        animatesDifferences: Bool = true,
        @ViewBuilder content: @escaping @MainActor (Data.Element) -> Content
    ) {
        self.init(
            identified: UIKitIdentifiedData(data, id: id), selection: selection.map { .single($0) } ?? .none,
            style: style, animatesDifferences: animatesDifferences, content: content
        )
    }

    /// Creates SwiftUI rows with stable IDs and multiple selection.
    ///
    /// IDs must be unique. The binding may retain IDs absent from the data;
    /// only present IDs are selected, so filtering does not discard selection.
    init<Data: RandomAccessCollection, Content: View>(
        _ data: Data,
        id: KeyPath<Data.Element, Item>,
        selection: Binding<Set<Item>>,
        style: UITableView.Style = .plain,
        animatesDifferences: Bool = true,
        @ViewBuilder content: @escaping @MainActor (Data.Element) -> Content
    ) {
        self.init(
            identified: UIKitIdentifiedData(data, id: id), selection: .multiple(selection),
            style: style, animatesDifferences: animatesDifferences, content: content
        )
    }

    /// Creates SwiftUI rows with stable IDs and optional single selection.
    ///
    /// IDs must be unique. The binding may retain IDs absent from the data;
    /// only present IDs are selected, so filtering does not discard selection.
    init<Data: RandomAccessCollection, Content: View>(
        _ data: Data,
        selection: Binding<Item?>? = nil,
        style: UITableView.Style = .plain,
        animatesDifferences: Bool = true,
        @ViewBuilder content: @escaping @MainActor (Data.Element) -> Content
    ) where Data.Element: Identifiable, Data.Element.ID == Item {
        self.init(
            data, id: \.id, selection: selection,
            style: style, animatesDifferences: animatesDifferences, content: content
        )
    }

    /// Creates SwiftUI rows with stable IDs and multiple selection.
    ///
    /// IDs must be unique. The binding may retain IDs absent from the data;
    /// only present IDs are selected, so filtering does not discard selection.
    init<Data: RandomAccessCollection, Content: View>(
        _ data: Data,
        selection: Binding<Set<Item>>,
        style: UITableView.Style = .plain,
        animatesDifferences: Bool = true,
        @ViewBuilder content: @escaping @MainActor (Data.Element) -> Content
    ) where Data.Element: Identifiable, Data.Element.ID == Item {
        self.init(
            data, id: \.id, selection: selection,
            style: style, animatesDifferences: animatesDifferences, content: content
        )
    }
}
