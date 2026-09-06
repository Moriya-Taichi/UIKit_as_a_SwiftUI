// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "UIKitSwiftUI",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .macCatalyst(.v16),
    ],
    products: [
        .library(name: "AppKitSwiftUI", targets: ["AppKitSwiftUI"]),
        .library(
            name: "UIKitSwiftUI",
            targets: ["UIKitSwiftUI"]
        ),
    ],
    targets: [
        .target(name: "AppKitSwiftUI"),
        .testTarget(name: "AppKitSwiftUITests", dependencies: ["AppKitSwiftUI"]),
        .target(name: "UIKitSwiftUI"),
        .testTarget(
            name: "UIKitSwiftUITests",
            dependencies: ["UIKitSwiftUI"]
        ),
    ]
)
