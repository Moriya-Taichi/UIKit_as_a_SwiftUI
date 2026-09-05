import SwiftUI
import UIKit
import XCTest
@testable import UIKitSwiftUI

@MainActor
private final class RefreshState: ObservableObject {
    @Published var isVisible = true
    let scrollView = UIScrollView()
    let originalControl = UIRefreshControl()
    var calls = 0
    var release = false
    var cancelled = false

    init() {
        scrollView.refreshControl = originalControl
    }

    func refresh() async {
        calls += 1
        do {
            while !release {
                try await Task<Never, Never>.sleep(nanoseconds: 10_000_000)
            }
        } catch {
            cancelled = Task.isCancelled
        }
    }
}

@MainActor
private struct RefreshHarness: View {
    @ObservedObject var state: RefreshState

    var body: some View {
        if state.isVisible {
            UIKitView(make: { state.scrollView })
                .frame(height: 200)
                .refreshable { await state.refresh() }
        }
    }
}

@MainActor
final class RefreshBridgeTests: XCTestCase {
    func testRefreshFinishesAndIgnoresOverlappingRequests() async throws {
        let state = RefreshState()
        let host = BridgeTestHost(RefreshHarness(state: state))
        defer { host.close() }
        let mounted = await waitForBridge {
            state.scrollView.refreshControl != nil
                && state.scrollView.refreshControl !== state.originalControl
        }
        XCTAssertTrue(mounted)
        let control = try XCTUnwrap(state.scrollView.refreshControl)
        control.sendActions(for: .valueChanged)
        control.sendActions(for: .valueChanged)
        let started = await waitForBridge { state.calls == 1 && control.isRefreshing }
        XCTAssertTrue(started)
        state.release = true
        let finished = await waitForBridge { !control.isRefreshing }
        XCTAssertTrue(finished)
        XCTAssertEqual(state.calls, 1)

        control.sendActions(for: .valueChanged)
        let repeated = await waitForBridge { state.calls == 2 && !control.isRefreshing }
        XCTAssertTrue(repeated)
    }

    func testDismantleCancelsRefreshAndRestoresAnExternalControl() async throws {
        let state = RefreshState()
        let host = BridgeTestHost(RefreshHarness(state: state))
        defer { host.close() }
        let mounted = await waitForBridge {
            state.scrollView.refreshControl != nil
                && state.scrollView.refreshControl !== state.originalControl
        }
        XCTAssertTrue(mounted)
        let control = try XCTUnwrap(state.scrollView.refreshControl)
        control.sendActions(for: .valueChanged)
        let started = await waitForBridge { state.calls == 1 }
        XCTAssertTrue(started)
        state.isVisible = false
        let stopped = await waitForBridge {
            state.cancelled && state.scrollView.refreshControl === state.originalControl
        }
        XCTAssertTrue(stopped)
        XCTAssertFalse(control.isRefreshing)
        control.sendActions(for: .valueChanged)
        XCTAssertEqual(state.calls, 1)
    }
}
