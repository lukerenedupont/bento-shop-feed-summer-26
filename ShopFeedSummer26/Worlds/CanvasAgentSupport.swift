import Foundation
import SwiftUI
import UIKit

/// Compatibility types for the canvas mechanics sourced from
/// shopify-playground/canvas-agent. The feed keeps its canonical merchant and
/// product models and only adapts them at this presentation boundary.
enum ProductTryKind: String, CaseIterable, Codable, Sendable {
    case room
    case face
    case wrist
    case footwear
    case upperBody

    var isWearable: Bool { self != .room }

    var actionTitle: String {
        switch self {
        case .room: "Place in your space"
        case .face: "Try near your face"
        case .wrist: "Try on your wrist"
        case .footwear: "Try on your feet"
        case .upperBody: "Try it on"
        }
    }

    var symbol: String {
        switch self {
        case .room: "viewfinder"
        case .face: "face.smiling"
        case .wrist: "applewatch"
        case .footwear: "shoe.2"
        case .upperBody: "tshirt"
        }
    }
}

struct CatalogProduct: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let merchant: String
    let price: Decimal
    let currencyCode: String
    let category: String
    let imageURL: URL
    let shopURL: URL
    let ratingValue: Double?
    let reviewCount: Int?
    let accentHex: String
    let tryKind: ProductTryKind

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }
}

struct CatalogCanvasDensity: Equatable {
    static let productsPerColumn = 10
    static let maximumColumnCount = 5

    static func columnCount(forDisplayedProductCount productCount: Int) -> Int {
        min(maximumColumnCount, max(1, Int(ceil(Double(productCount) / Double(productsPerColumn)))))
    }

    static func resolvedColumnCount(
        configuredColumnCount: Int?,
        displayedProductCount: Int
    ) -> Int? {
        guard configuredColumnCount != nil else { return nil }
        return columnCount(forDisplayedProductCount: displayedProductCount)
    }
}

enum ShopDropStyle {
    static let ink = Color(hex: "#171816")
    static let muted = Color(hex: "#6D716B")
    static let canvas = Color.white
    static let experienceCornerRadius: CGFloat = 0

    static func experienceFrame(in bounds: CGRect) -> CGRect { bounds }
}

enum CanvasAgentProductAdapter {
    static func products(from resolved: [ResolvedStoryProduct]) -> [CatalogProduct] {
        resolved.compactMap { item in
            guard let image = item.product.imageURL.flatMap(URL.init(string:)) else { return nil }
            let shopURL = item.product.shopURL.flatMap(URL.init(string:))
                ?? URL(string: "https://shop.app")!
            return CatalogProduct(
                id: item.id,
                title: item.product.title,
                merchant: item.merchant.displayName,
                price: decimalPrice(item.product.price),
                currencyCode: item.product.currencyCode,
                category: item.product.productType ?? "Product",
                imageURL: image,
                shopURL: shopURL,
                ratingValue: nil,
                reviewCount: nil,
                accentHex: "#EDEBE7",
                tryKind: tryKind(for: item.product)
            )
        }
    }

    private static func decimalPrice(_ value: String) -> Decimal {
        let filtered = value.filter { $0.isNumber || $0 == "." }
        return Decimal(string: filtered) ?? 0
    }

    private static func tryKind(for product: SampleMerchant.Product) -> ProductTryKind {
        let text = "\(product.title) \(product.productType ?? "")".lowercased()
        if text.contains("watch") { return .wrist }
        if text.contains("glass") || text.contains("frame") { return .face }
        if text.contains("shoe") || text.contains("sneaker") || text.contains("boot") { return .footwear }
        if text.contains("shirt") || text.contains("jacket") || text.contains("hoodie") { return .upperBody }
        return .room
    }
}
