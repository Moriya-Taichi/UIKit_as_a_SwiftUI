#if os(macOS)
import Foundation
import SwiftUI
import AppKit
import XCTest
@testable import AppKitSwiftUI

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
            AppKitTextField(resource, text: .constant(""))
                .configureAppKit { $0.identifier = "localized-field" }
            AppKitSearchField(resource, text: .constant(""))
                .configureAppKit { $0.identifier = "localized-search" }
            AppKitButton(resource) {}
                .configureAppKit { $0.identifier = "localized-button" }
            AppKitView(make: { NSTextField(labelWithString: "") })
                .text(localized: resource)
                .configureAppKit { $0.identifier = "localized-label" }
            AppKitTextField(verbatim: "PersonName", text: .constant(""))
                .configureAppKit { $0.identifier = "verbatim-field" }
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
            "CFBundleIdentifier": "AppKitSwiftUITests.Localization",
            "CFBundleDevelopmentRegion": "en",
            "CFBundleLocalizations": ["en", "ja"],
        ]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: bundleURL.appendingPathComponent("Info.plist"))
        let resource = LocalizedStringResource("PersonName", bundle: .atURL(bundleURL))
        let state = LocalizationState()
        let host = AppKitBridgeTestHost(LocalizationHarness(state: state, resource: resource))
        defer { host.close() }
        try await waitForAppKit {
            host.find(NSTextField.self, id: "localized-field")?.placeholderString == "Name"
                && host.find(NSTextField.self, id: "localized-label")?.stringValue == "Name"
        }
        let field = try XCTUnwrap(host.find(NSTextField.self, id: "localized-field"))
        let search = try XCTUnwrap(host.find(NSSearchField.self, id: "localized-search"))
        let button = try XCTUnwrap(host.find(NSButton.self, id: "localized-button"))
        XCTAssertEqual(search.placeholderString, "Name")
        XCTAssertEqual(button.title, "Name")

        state.locale = Locale(identifier: "ja")
        try await waitForAppKit {
            field.placeholderString == "名前" && search.placeholderString == "名前"
                && button.title == "名前"
                && host.find(NSTextField.self, id: "localized-label")?.stringValue == "名前"
        }
        XCTAssertEqual(host.find(NSTextField.self, id: "verbatim-field")?.placeholderString, "PersonName")
        XCTAssertTrue(host.find(NSTextField.self, id: "localized-field") === field)
    }
}
#endif
