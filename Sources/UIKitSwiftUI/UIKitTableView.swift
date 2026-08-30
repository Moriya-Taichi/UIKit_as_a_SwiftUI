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

    private let model: UIKitListModel<SectionID, Item>
    private let style: UITableView.Style
    private let animatesDifferences: Bool
    private let configure: @MainActor (UITableView) -> Void
    private let cell: CellProvider

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
        self.style = style
        self.animatesDifferences = animatesDifferences
        self.configure = configure
        self.cell = cell
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
        fileprivate var cellProvider: CellProvider
        fileprivate var dataSource:
            UITableViewDiffableDataSource<SectionID, Item>?

        fileprivate init(
            model: UIKitListModel<SectionID, Item>?,
            cellProvider: @escaping CellProvider
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
        }

        public func tableView(
            _ tableView: UITableView,
            didDeselectRowAt indexPath: IndexPath
        ) {
            guard let item = dataSource?.itemIdentifier(for: indexPath) else {
                return
            }
            model?.handleDeselected(item)
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

        // The SDK's cell provider is not actor-annotated on every supported
        // SDK, and the data source only calls it on the main actor. The cell
        // leaves the assumption through a `nonisolated(unsafe)` local because
        // `assumeIsolated` constrains its own result type on some toolchains.
        let dataSource = UITableViewDiffableDataSource<SectionID, Item>(
            tableView: tableView
        ) { [weak coordinator] tableView, indexPath, item in
            nonisolated(unsafe) var cell: UITableViewCell? = nil
            MainActor.assumeIsolated {
                cell = coordinator?.cellProvider(tableView, indexPath, item)
            }
            return cell
        }
        coordinator.dataSource = dataSource

        tableView.delegate = coordinator
        configure(tableView)
        dataSource.apply(model.snapshot(), animatingDifferences: false)
        return tableView
    }

    public func updateUIView(_ uiView: UITableView, context: Context) {
        let coordinator = context.coordinator
        coordinator.model = model
        coordinator.cellProvider = cell
        configure(uiView)
        if uiView.delegate !== coordinator {
            uiView.delegate = coordinator
        }

        guard let dataSource = coordinator.dataSource else { return }
        // Reading the model here makes the update depend on its observable
        // state, so SwiftUI re-invokes `updateUIView` when the model changes.
        let updated = model.snapshot()
        dataSource.apply(
            Self.updateSnapshot(
                current: dataSource.snapshot(),
                updated: updated
            ),
            animatingDifferences: animatesDifferences
        )
    }

    public static func dismantleUIView(
        _ uiView: UITableView,
        coordinator: Coordinator
    ) {
        if uiView.delegate === coordinator {
            uiView.delegate = nil
        }
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
