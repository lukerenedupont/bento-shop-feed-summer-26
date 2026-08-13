import Foundation

/// A personalized piece of commerce content. The format is intentionally
/// finite; the title, thesis, products, and generated treatment create the
/// variation rather than a merchant-specific card type.
struct FeedStory: Identifiable, Hashable, Codable {
    enum Format: String, Hashable, Codable {
        case world
        case shortlist
        case setup
    }

    struct ProductReference: Hashable, Codable {
        let merchantID: String
        let productID: Int
    }

    let id: String
    let eyebrow: String
    let title: String
    let subtitle: String
    let format: Format
    let topicKeys: Set<String>
    let accentHex: String
    /// Bundled editorial atmosphere shared by the Made for You card and its
    /// canonical topic destination. Commerce imagery remains product-driven.
    let coverImageName: String?
    let destinationLabel: String
    let products: [ProductReference]

    func resolvedProducts(from merchants: [SampleMerchant]) -> [ResolvedStoryProduct] {
        products.compactMap { reference in
            guard let merchant = merchants.first(where: { $0.id == reference.merchantID }),
                  let product = merchant.products.first(where: { $0.id == reference.productID }) else {
                return nil
            }
            return ResolvedStoryProduct(merchant: merchant, product: product)
        }
    }
}

struct ResolvedStoryProduct: Identifiable {
    let merchant: SampleMerchant
    let product: SampleMerchant.Product

    var id: String { "\(merchant.id)-\(product.id)" }
}
