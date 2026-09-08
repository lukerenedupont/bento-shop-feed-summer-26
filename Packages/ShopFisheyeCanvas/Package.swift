// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShopFisheyeCanvas",
    platforms: [.iOS("18.0")],
    products: [.library(name: "ShopFisheyeCanvas", targets: ["ShopFisheyeCanvas"])],
    targets: [.target(name: "ShopFisheyeCanvas")]
)
