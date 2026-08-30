// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "UIKitSwiftUI",
    platforms: [
        .iOS(.v16),
        .macCatalyst(.v16),
    ],
    products: [
        .library(
            name: "UIKitSwiftUI",
            targets: ["UIKitSwiftUI"]
        ),
    ],
    targets: [
        .target(name: "UIKitSwiftUI"),
        .testTarget(
            name: "UIKitSwiftUITests",
            dependencies: ["UIKitSwiftUI"]
        ),
    ]
)

