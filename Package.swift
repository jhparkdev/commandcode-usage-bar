// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CommandCodeUsageBar",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "CommandCodeUsageBar", targets: ["CommandCodeUsageBar"]),
        .executable(name: "UsageCoreTestRunner", targets: ["UsageCoreTestRunner"])
    ],
    targets: [
        .target(
            name: "UsageCore",
            path: "Sources/UsageCore",
            swiftSettings: [.unsafeFlags(["-enable-testing"])],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        // Liquid Glass 디자인 시스템 (macOS 26 API 전용)
        .target(
            name: "GlassUI",
            path: "Sources/GlassUI"
        ),
        .executableTarget(
            name: "CommandCodeUsageBar",
            dependencies: ["UsageCore", "GlassUI"],
            path: "Sources/CommandCodeUsageBar"
        ),
        // 이 머신에는 Xcode 가 없어 XCTest / swift-testing 런타임을 쓸 수 없다.
        // 의존성 없이 동작하는 자체 러너로 테스트를 실행한다.
        .executableTarget(
            name: "UsageCoreTestRunner",
            dependencies: ["UsageCore", "GlassUI"],
            path: "Sources/UsageCoreTestRunner"
        )
    ]
)
