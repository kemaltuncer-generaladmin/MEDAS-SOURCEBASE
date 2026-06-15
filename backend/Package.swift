// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SourceBaseBackend",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SourceBaseBackend", targets: ["SourceBaseBackend"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "SourceBaseBackend",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "Sources/SourceBaseBackend"
        ),
        .testTarget(
            name: "SourceBaseBackendTests",
            dependencies: ["SourceBaseBackend"],
            path: "Tests/SourceBaseBackendTests"
        )
    ]
)
