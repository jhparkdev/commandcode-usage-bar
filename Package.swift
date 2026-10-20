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
        ),
        // Liquid Glass 디자인 시스템 (macOS 26 API 전용)
        .target(
            name: "GlassUI",
            path: "Sources/GlassUI"
        )
    ]
)
