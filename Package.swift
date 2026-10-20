// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CommandCodeUsageBar",
    platforms: [.macOS("26.0")],
    products: [],
    targets: [
        .target(
            name: "UsageCore",
            path: "Sources/UsageCore",
            linkerSettings: [.linkedLibrary("sqlite3")]
        )
    ]
)
