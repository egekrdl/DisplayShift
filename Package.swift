// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DisplayShift",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "DisplayShiftCore",
            path: "DisplayShift",
            exclude: ["App", "Views", "ViewModels", "Resources", "Services/Displays.swift", "Services/GlobalShortcuts.swift", "Services/PrivateUpdates.swift"],
            sources: ["Models", "Services/PresetStore.swift"]
        ),
        .testTarget(name: "DisplayShiftCoreTests", dependencies: ["DisplayShiftCore"], path: "Tests")
    ]
)
