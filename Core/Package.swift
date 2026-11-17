// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WAIHCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "WAIHCore", targets: ["WAIHCore"]),
    ],
    targets: [
        .target(name: "WAIHCore"),
        .testTarget(name: "WAIHCoreTests", dependencies: ["WAIHCore"]),
    ],
    swiftLanguageModes: [.v5]
)
