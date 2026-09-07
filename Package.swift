// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RClickReplacement",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "RClickHost", targets: ["RClickHost"]),
        .executable(name: "RClickFinder", targets: ["RClickFinder"])
    ],
    targets: [
        .executableTarget(name: "RClickHost"),
        .executableTarget(
            name: "RClickFinder",
            linkerSettings: [
                // Finder Sync extensions are launched by PlugInKit through this entry point.
                .unsafeFlags(["-Xlinker", "-e", "-Xlinker", "_NSExtensionMain"])
            ]
        )
    ]
)
