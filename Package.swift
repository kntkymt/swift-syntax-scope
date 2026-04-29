// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-syntax-scope",
    platforms: [
        .macOS(.v13), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)
    ],
    products: [
        .library(name: "SwiftSyntaxScope", targets: ["SwiftSyntaxScope"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "509.0.0"..<"604.0.0"),
        .package(url: "https://github.com/kntkymt/swift-gsb-macro", from: "0.2.0"),
    ],
    targets: [
        .target(
            name: "SwiftSyntaxScope",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "GSB", package: "swift-gsb-macro"),
            ]
        ),
        .testTarget(
            name: "SwiftSyntaxScopeTests",
            dependencies: ["SwiftSyntaxScope"]
        ),
    ]
)
