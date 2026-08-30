import SwiftUI
import UIKit

/// A UIKit collection view whose data comes from an observable
/// `UIKitListModel`.
///
/// The model owns the sections, the items, and the selection; the bridge owns
/// a `UICollectionViewDiffableDataSource` built from the model's snapshot.
/// Callers never implement `UICollectionViewDataSource`: they only describe
/// how an item configures a cell. The cell registration is created exactly
/// once per collection view, while the configuration closure is refreshed on
/// every update so it may capture current SwiftUI state.
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

    private let model: UIKitListModel<SectionID, Item>
    private let layout: @MainActor () -> UICollectionViewLayout
    private let animatesDifferences: Bool
    private let configure: @MainActor (UICollectionView) -> Void
    private let updateCell: CellUpdate
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
        self.model = model
        self.layout = layout
        self.animatesDifferences = animatesDifferences
        self.configure = configure
        updateCell = { dequeued, indexPath, item in
            guard let typed = dequeued as? Cell else { return }
            cell(typed, indexPath, item)
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
                    coordinator.updateCell(dequeued, indexPath, item)
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
        fileprivate var updateCell: CellUpdate
        fileprivate var cellProvider: CellProvider?
        fileprivate var dataSource:
            UICollectionViewDiffableDataSource<SectionID, Item>?

        fileprivate init(
            model: UIKitListModel<SectionID, Item>?,
            updateCell: @escaping CellUpdate
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
        }

        public func collectionView(
            _ collectionView: UICollectionView,
            didDeselectItemAt indexPath: IndexPath
        ) {
            guard let item = dataSource?.itemIdentifier(for: indexPath) else {
                return
            }
            model?.handleDeselected(item)
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

        collectionView.delegate = coordinator
        configure(collectionView)
        dataSource.apply(model.snapshot(), animatingDifferences: false)
        return collectionView
    }

    public func updateUIView(_ uiView: UICollectionView, context: Context) {
        let coordinator = context.coordinator
        coordinator.model = model
        coordinator.updateCell = updateCell
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
        _ uiView: UICollectionView,
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
