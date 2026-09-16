// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KeepAwake",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure, Foundation-only logic — no AppKit, so it's unit-testable headlessly.
        .target(name: "KeepAwakeCore"),
        // The menu-bar app itself (AppKit). build.sh wraps this binary in a .app.
        .executableTarget(name: "KeepAwake", dependencies: ["KeepAwakeCore"]),
        // Tests for the core logic. A plain executable (not XCTest) so it runs
        // with Command Line Tools alone — XCTest ships only with full Xcode.
        // Run with `swift run KeepAwakeTests` (or `make test`).
        .executableTarget(name: "KeepAwakeTests", dependencies: ["KeepAwakeCore"]),
    ]
)
