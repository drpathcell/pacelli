// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PacelliKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PacelliKit", targets: ["PacelliKit"])
    ],
    targets: [
        .target(name: "PacelliKit"),
        .testTarget(name: "PacelliKitTests", dependencies: ["PacelliKit"]),
    ]
)
