#if canImport(UIKit)
import Foundation

/// Resolves localized UIKit strings again when SwiftUI's locale changes.
enum UIKitDisplayText {
    case verbatim(String)
    case localized(LocalizedStringResource)

    func resolve(in locale: Locale) -> String {
        switch self {
        case .verbatim(let text):
            return text
        case .localized(var resource):
            resource.locale = locale
            return String(localized: resource)
        }
    }
}
#endif
