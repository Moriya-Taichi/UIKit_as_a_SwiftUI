import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import UIKitSwiftUI

@MainActor
private final class LocalizationState: ObservableObject {
    @Published var locale = Locale(identifier: "en")
}

@MainActor
private struct LocalizationHarness: View {
    @ObservedObject var state: LocalizationState
    let resource: LocalizedStringResource

    var body: some View {
        VStack {
            UIKitTextField(localized: resource, text: .constant(""))
                .configureUIKit { $0.accessibilityIdentifier = "localized-field" }
            UIKitSearchBar(localizedPrompt: resource, text: .constant(""))
                .configureUIKit { $0.accessibilityIdentifier = "localized-search" }
            UIKitButton(localized: resource) {}
                .configureUIKit { $0.accessibilityIdentifier = "localized-button" }
            UIKitView(make: UILabel.init)
                .text(localized: resource)
                .configureUIKit { $0.accessibilityIdentifier = "localized-label" }
            UIKitTextField(verbatim: "PersonName", text: .constant(""))
                .configureUIKit { $0.accessibilityIdentifier = "verbatim-field" }
        }
        .environment(\.locale, state.locale)
    }
}

@MainActor
final class LocalizationBridgeTests: XCTestCase {
    func testLocalizedInputsKeepResourceBundleAndFollowEnvironmentLocale() async throws {
        // A resource-only bundle makes the lookup independent of the test
        // runner's own preferred localizations and developer machine locale.
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("bundle")
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        for (language, translation) in [("en", "Name"), ("ja", "名前")] {
            let directory = bundleURL.appendingPathComponent("\(language).lproj")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try "\"PersonName\" = \"\(translation)\";".write(
                to: directory.appendingPathComponent("Localizable.strings"),
                atomically: true, encoding: .utf8
            )
        }
        let info: [String: Any] = [
            "CFBundleIdentifier": "UIKitSwiftUITests.Localization",
            "CFBundleDevelopmentRegion": "en",
            "CFBundleLocalizations": ["en", "ja"],
        ]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: bundleURL.appendingPathComponent("Info.plist"))
        let resource = LocalizedStringResource("PersonName", bundle: .atURL(bundleURL))
        let state = LocalizationState()
        let host = BridgeTestHost(LocalizationHarness(state: state, resource: resource))
        defer { host.close() }
        let mounted = await waitForBridge {
            host.view(UITextField.self, id: "localized-field")?.placeholder == "Name"
                && host.view(UILabel.self, id: "localized-label")?.text == "Name"
        }
        XCTAssertTrue(mounted)
        let field = try XCTUnwrap(host.view(UITextField.self, id: "localized-field"))
        let search = try XCTUnwrap(host.view(UISearchBar.self, id: "localized-search"))
        let button = try XCTUnwrap(host.view(UIButton.self, id: "localized-button"))
        XCTAssertEqual(search.placeholder, "Name")
        XCTAssertEqual(button.configuration?.title, "Name")

        state.locale = Locale(identifier: "ja")
        let translated = await waitForBridge {
            field.placeholder == "名前" && search.placeholder == "名前"
                && button.configuration?.title == "名前"
                && host.view(UILabel.self, id: "localized-label")?.text == "名前"
        }
        XCTAssertTrue(translated)
        XCTAssertEqual(host.view(UITextField.self, id: "verbatim-field")?.placeholder, "PersonName")
        XCTAssertTrue(host.view(UITextField.self, id: "localized-field") === field)
    }
}
