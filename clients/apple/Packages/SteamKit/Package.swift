// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SteamKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "SteamKit", targets: ["SteamKit"]),
    ],
    targets: [
        .target(
            name: "SteamKit",
            path: "Sources/SteamKit"
        ),
        .testTarget(
            name: "SteamKitTests",
            dependencies: ["SteamKit"],
            path: "Tests/SteamKitTests"
        ),
    ]
)
