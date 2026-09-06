#if canImport(UIKit)
import SwiftUI
import UIKit

/// A UIKit collection view displaying SwiftUI rows or UIKit cells.
///
/// Data initializers use stable IDs and optional selection bindings; row
/// content is built with `UIHostingConfiguration`. Model initializers retain
/// the existing `UIKitListModel` and UIKit cell-provider API. The bridge owns
/// its diffable data source and forwards selection through the selected mode.
@available(iOS 17.0, macCatalyst 17.0, *)
@MainActor
public struct UIKitCollectionView<
    SectionID: Hashable & Sendable,
    Item: Hashable & Sendable
>: UIViewRepresentable {
    public typealias UIViewType = UICollectionView

    /// Applies an item to a dequeued cell, after the bridge has erased the
    /// caller's concrete cell type.
    public typealias CellUpdate = @MainActor (
        UICollectionViewCell,
        IndexPath,
        Item
    ) -> Void

    /// Dequeues the cell for an item. Built once per collection view, because
    /// it owns the cell registration.
    public typealias CellProvider = @MainActor (
        UICollectionView,
        IndexPath,
        Item
    ) -> UICollectionViewCell

    private let model: UIKitListModel<SectionID, Item>?
    // Built while SwiftUI evaluates the caller's body so reading `sections`
    // establishes the observation dependency that recreates this value.
    private let snapshot: NSDiffableDataSourceSnapshot<SectionID, Item>
    private let layout: @MainActor () -> UICollectionViewLayout
    private let animatesDifferences: Bool
    private var configure: @MainActor (UICollectionView) -> Void
    fileprivate typealias ContextualCellUpdate = @MainActor (
        UICollectionViewCell, IndexPath, Item, EnvironmentValues
    ) -> Void
    private let updateCell: ContextualCellUpdate
    private var selection: UIKitListSelection<Item> = .unmanaged
    private var selectedIDs: Set<Item>?
    private let makeCellProvider: @MainActor (Coordinator) -> CellProvider

    /// Creates a collection view that dequeues cells of the given type.
    ///
    /// The registration for `cellType` is managed internally and created
    /// exactly once per collection view; `cell` configures every dequeued
    /// cell and is refreshed on every update. Every visible cell is
    /// reconfigured on each update, so the state `cell` captures stays
    /// current even when the items themselves are unchanged.
    public init<Cell: UICollectionViewCell>(
        model: UIKitListModel<SectionID, Item>,
        layout: @escaping @MainActor () -> UICollectionViewLayout,
        animatesDifferences: Bool = true,
        cellType: Cell.Type,
        configure: @escaping @MainActor (UICollectionView) -> Void = { _ in },
        cell: @escaping @MainActor (Cell, IndexPath, Item) -> Void
    ) {
        self.init(
            snapshot: model.snapshot(), model: model, selection: .unmanaged,
            layout: layout, animatesDifferences: animatesDifferences,
            cellType: cellType, configure: configure,
            cell: { cellView, indexPath, item, _ in cell(cellView, indexPath, item) }
        )
    }

    private init<Cell: UICollectionViewCell>(
        snapshot: NSDiffableDataSourceSnapshot<SectionID, Item>,
        model: UIKitListModel<SectionID, Item>?,
        selection: UIKitListSelection<Item>,
        layout: @escaping @MainActor () -> UICollectionViewLayout,
        animatesDifferences: Bool,
        cellType: Cell.Type,
        configure: @escaping @MainActor (UICollectionView) -> Void,
        cell: @escaping @MainActor (Cell, IndexPath, Item, EnvironmentValues) -> Void
    ) {
        self.model = model
        self.snapshot = snapshot
        self.selection = selection
        selectedIDs = selection.ids
        self.layout = layout
        self.animatesDifferences = animatesDifferences
        self.configure = configure
        updateCell = { dequeued, indexPath, item, environment in
            guard let typed = dequeued as? Cell else { return }
            cell(typed, indexPath, item, environment)
        }
        makeCellProvider = { coordinator in
            // The registration is created here, inside the provider that
            // `makeUIView` builds once, never per update.
            let registration = UICollectionView.CellRegistration<Cell, Item> {
                [weak coordinator] dequeued, indexPath, item in
                // The registration handler is not actor-annotated on every
                // supported SDK, and it only runs on the main actor.
                MainActor.assumeIsolated {
                    guard let coordinator else { return }
                    coordinator.updateCell(dequeued, indexPath, item, coordinator.environmentValues)
                }
            }
            return { collectionView, indexPath, item in
                collectionView.dequeueConfiguredReusableCell(
                    using: registration,
                    for: indexPath,
                    item: item
                )
            }
        }
    }

    /// Creates a collection view whose cells are list cells configured from
    /// the content the closure returns.
    ///
    /// Every visible cell is reconfigured on each update, so the state the
    /// closure captures stays current even when the items themselves are
    /// unchanged.
    public init(
        model: UIKitListModel<SectionID, Item>,
        layout: @escaping @MainActor () -> UICollectionViewLayout,
        animatesDifferences: Bool = true,
        configure: @escaping @MainActor (UICollectionView) -> Void = { _ in },
        content: @escaping @MainActor (Item) -> UIListContentConfiguration
    ) {
        self.init(
            model: model,
            layout: layout,
            animatesDifferences: animatesDifferences,
            cellType: UICollectionViewListCell.self,
            configure: configure,
            cell: { cell, _, item in
                cell.contentConfiguration = content(item)
            }
        )
    }

    /// Keeps the cell registration, the diffable data source, and forwards
    /// selection to the model.
    @MainActor
    public final class Coordinator: NSObject, UICollectionViewDelegate {
        fileprivate var model: UIKitListModel<SectionID, Item>?
        fileprivate let environment = UIKitEnvironmentState()
        fileprivate var environmentValues = EnvironmentValues()
        fileprivate var selection: UIKitListSelection<Item> = .unmanaged
        fileprivate var selectedIDs: Set<Item>?
        fileprivate var updateCell: ContextualCellUpdate
        fileprivate var cellProvider: CellProvider?
        fileprivate var dataSource:
            UICollectionViewDiffableDataSource<SectionID, Item>?

        fileprivate init(
            model: UIKitListModel<SectionID, Item>?,
            updateCell: @escaping ContextualCellUpdate
        ) {
            self.model = model
            self.updateCell = updateCell
        }

        public func collectionView(
            _ collectionView: UICollectionView,
            didSelectItemAt indexPath: IndexPath
        ) {
            guard let item = dataSource?.itemIdentifier(for: indexPath) else {
                return
            }
            model?.handleSelected(item)
            selection.select(item)
            selectedIDs = selection.ids
        }

        public func collectionView(
            _ collectionView: UICollectionView,
            didDeselectItemAt indexPath: IndexPath
        ) {
            guard let item = dataSource?.itemIdentifier(for: indexPath) else {
                return
            }
            model?.handleDeselected(item)
            selection.deselect(item)
            selectedIDs = selection.ids
        }

        fileprivate func configureSelection(_ collectionView: UICollectionView) {
            if let allowsSelection = selection.allowsSelection {
                collectionView.allowsSelection = allowsSelection
            }
            if let multiple = selection.allowsMultipleSelection {
                collectionView.allowsMultipleSelection = multiple
            }
        }

        fileprivate func synchronizeSelection(_ collectionView: UICollectionView) {
            guard let selectedIDs, let dataSource else { return }
            let desired = Set(selectedIDs.compactMap { dataSource.indexPath(for: $0) })
            let current = Set(collectionView.indexPathsForSelectedItems ?? [])
            for indexPath in current.subtracting(desired) {
                collectionView.deselectItem(at: indexPath, animated: false)
            }
            for indexPath in desired.subtracting(current) {
                collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(model: model, updateCell: updateCell)
    }

    public func makeUIView(context: Context) -> UICollectionView {
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout()
        )

        let coordinator = context.coordinator
        coordinator.model = model
        coordinator.updateCell = updateCell
        coordinator.environmentValues = context.environment
        coordinator.selection = selection
        coordinator.selectedIDs = selectedIDs
        // Built once per collection view, so the cell registration it owns is
        // never recreated by an update.
        coordinator.cellProvider = makeCellProvider(coordinator)

        // The SDK's cell provider is not actor-annotated on every supported
        // SDK, and the data source only calls it on the main actor. The cell
        // leaves the assumption through a `nonisolated(unsafe)` local because
        // `assumeIsolated` constrains its own result type on some toolchains.
        let dataSource = UICollectionViewDiffableDataSource<SectionID, Item>(
            collectionView: collectionView
        ) { [weak coordinator] collectionView, indexPath, item in
            nonisolated(unsafe) var cell: UICollectionViewCell? = nil
            MainActor.assumeIsolated {
                cell = coordinator?.cellProvider?(
                    collectionView,
                    indexPath,
                    item
                )
            }
            return cell
        }
        coordinator.dataSource = dataSource

        coordinator.environment.update(collectionView, environment: context.environment, configure: configure)
        collectionView.delegate = coordinator
        collectionView.dataSource = dataSource
        coordinator.configureSelection(collectionView)
        dataSource.apply(snapshot, animatingDifferences: false) { [weak coordinator, weak collectionView] in
            MainActor.assumeIsolated {
                if let collectionView { coordinator?.synchronizeSelection(collectionView) }
            }
        }
        return collectionView
    }

    public func updateUIView(_ uiView: UICollectionView, context: Context) {
        let coordinator = context.coordinator
        coordinator.model = model
        coordinator.updateCell = updateCell
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
        _ uiView: UICollectionView,
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
    /// path, because the configuration closure captures SwiftUI state that
    /// may have moved on. Reconfiguration re-invokes the registration handler
    /// for the item's existing cell instead of replacing the cell, so the
    /// diff stays a no-op while the content refreshes.
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
extension UIKitCollectionView: UIKitViewConfiguring {
    public typealias UIKitViewType = UICollectionView

    /// Appends UIKit configuration to each update.
    public func configureUIKit(_ body: @escaping @MainActor (UICollectionView) -> Void) -> Self {
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
extension UIKitCollectionView where SectionID == Int {
    private init<Element, Content: View>(
        identified data: UIKitIdentifiedData<Element, Item>,
        selection: UIKitListSelection<Item>,
        layout: @escaping @MainActor () -> UICollectionViewLayout,
        animatesDifferences: Bool,
        @ViewBuilder content: @escaping @MainActor (Element) -> Content
    ) {
        self.init(
            snapshot: data.snapshot, model: nil, selection: selection,
            layout: layout, animatesDifferences: animatesDifferences,
            cellType: UICollectionViewListCell.self, configure: { _ in },
            cell: { cell, _, id, environment in
                if let element = data.elements[id] {
                    cell.contentConfiguration = UIHostingConfiguration {
                        content(element).id(id).environment(\.self, environment)
                    }
                } else {
                    cell.contentConfiguration = nil
                }
            }
        )
    }
}

@available(iOS 17.0, macCatalyst 17.0, *)
public extension UIKitCollectionView where SectionID == Int {

    /// Creates SwiftUI rows with stable IDs and optional single selection.
    ///
    /// IDs must be unique. The binding may retain IDs absent from the data;
    /// only present IDs are selected, so filtering does not discard selection.
    init<Data: RandomAccessCollection, Content: View>(
        _ data: Data,
        id: KeyPath<Data.Element, Item>,
        selection: Binding<Item?>? = nil,
        layout: @escaping @MainActor () -> UICollectionViewLayout,
        animatesDifferences: Bool = true,
        @ViewBuilder content: @escaping @MainActor (Data.Element) -> Content
    ) {
        self.init(
            identified: UIKitIdentifiedData(data, id: id), selection: selection.map { .single($0) } ?? .none,
            layout: layout, animatesDifferences: animatesDifferences, content: content
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
        layout: @escaping @MainActor () -> UICollectionViewLayout,
        animatesDifferences: Bool = true,
        @ViewBuilder content: @escaping @MainActor (Data.Element) -> Content
    ) {
        self.init(
            identified: UIKitIdentifiedData(data, id: id), selection: .multiple(selection),
            layout: layout, animatesDifferences: animatesDifferences, content: content
        )
    }

    /// Creates SwiftUI rows with stable IDs and optional single selection.
    ///
    /// IDs must be unique. The binding may retain IDs absent from the data;
    /// only present IDs are selected, so filtering does not discard selection.
    init<Data: RandomAccessCollection, Content: View>(
        _ data: Data,
        selection: Binding<Item?>? = nil,
        layout: @escaping @MainActor () -> UICollectionViewLayout,
        animatesDifferences: Bool = true,
        @ViewBuilder content: @escaping @MainActor (Data.Element) -> Content
    ) where Data.Element: Identifiable, Data.Element.ID == Item {
        self.init(
            data, id: \.id, selection: selection,
            layout: layout, animatesDifferences: animatesDifferences, content: content
        )
    }

    /// Creates SwiftUI rows with stable IDs and multiple selection.
    ///
    /// IDs must be unique. The binding may retain IDs absent from the data;
    /// only present IDs are selected, so filtering does not discard selection.
    init<Data: RandomAccessCollection, Content: View>(
        _ data: Data,
        selection: Binding<Set<Item>>,
        layout: @escaping @MainActor () -> UICollectionViewLayout,
        animatesDifferences: Bool = true,
        @ViewBuilder content: @escaping @MainActor (Data.Element) -> Content
    ) where Data.Element: Identifiable, Data.Element.ID == Item {
        self.init(
            data, id: \.id, selection: selection,
            layout: layout, animatesDifferences: animatesDifferences, content: content
        )
    }
}
#endif
