// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShopCompositionCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ShopCompositionCore", targets: ["ShopCompositionCore"]),
        .executable(name: "composition-check", targets: ["CompositionCheck"])
    ],
    targets: [
        .target(name: "ShopCompositionCore"),
        .executableTarget(name: "CompositionCheck", dependencies: ["ShopCompositionCore"])
    ]
)
