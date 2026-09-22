// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JulianAgentUI",
    defaultLocalization: "en",
    platforms: [.iOS("26.0")],
    products: [.library(name: "JulianAgentUI", targets: ["JulianAgentUI"])],
    dependencies: [.package(url: "https://github.com/kean/Nuke.git", exact: "13.0.6")],
    targets: [
        .target(name: "Gravity", path: "Gravity", exclude: ["Tests"], sources: ["Sources"], resources: [.process("Resources")]),
        .target(name: "JulianAgentUI", dependencies: ["Gravity", .product(name: "Nuke", package: "Nuke")], resources: [.process("Resources")])
    ],
    swiftLanguageModes: [.v5]
)
