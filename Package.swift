// swift-tools-version: 5.9
// BBConnect — BudgetBakers hosted connect-flow Link SDK (WP4.3, DESIGN.md §9.2).
// Pure browser orchestration: no network calls, no API key.
import PackageDescription

let package = Package(
    name: "BBConnect",
    platforms: [
        // ASWebAuthenticationSession availability.
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "BBConnect", targets: ["BBConnect"])
    ],
    targets: [
        .target(name: "BBConnect", path: "Sources/BBConnect"),
        .testTarget(
            name: "BBConnectTests",
            dependencies: ["BBConnect"],
            path: "Tests/BBConnectTests"
        ),
    ]
)
