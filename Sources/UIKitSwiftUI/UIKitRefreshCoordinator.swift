#if canImport(UIKit)
import SwiftUI
import UIKit

/// Owns only the refresh control installed by the bridge and one refresh task.
@MainActor
final class UIKitRefreshCoordinator {
    private weak var scrollView: UIScrollView?
    private var control: UIRefreshControl?
    private var controlAction: UIAction?
    private var previousControl: UIRefreshControl?
    private var action: RefreshAction?
    private var task: Task<Void, Never>?
    private var generation = 0

    func update(_ scrollView: UIScrollView, action: RefreshAction?) {
        self.action = action
        guard action != nil else {
            dismantle()
            return
        }
        if self.scrollView !== scrollView {
            dismantle()
            self.action = action
            self.scrollView = scrollView
        }
        if control == nil {
            let control = UIRefreshControl()
            let controlAction = UIAction { [weak self] _ in self?.refresh() }
            control.addAction(controlAction, for: .valueChanged)
            self.control = control
            self.controlAction = controlAction
        }
        if scrollView.refreshControl !== control {
            previousControl = scrollView.refreshControl
            scrollView.refreshControl = control
        }
    }

    private func refresh() {
        guard task == nil else { return }
        guard let action else {
            control?.endRefreshing()
            return
        }
        control?.beginRefreshing()
        generation += 1
        let currentGeneration = generation
        task = Task { @MainActor [weak self] in
            await action()
            guard let self, self.generation == currentGeneration else { return }
            self.control?.endRefreshing()
            self.task = nil
        }
    }

    func dismantle() {
        generation += 1
        task?.cancel()
        task = nil
        action = nil
        control?.endRefreshing()
        if let controlAction {
            control?.removeAction(controlAction, for: .valueChanged)
        }
        if let control, scrollView?.refreshControl === control {
            scrollView?.refreshControl = previousControl
        }
        control = nil
        controlAction = nil
        previousControl = nil
        scrollView = nil
    }
}
#endif
