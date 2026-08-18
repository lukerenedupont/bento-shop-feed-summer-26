import Foundation

/// A collection-level merchant treatment is only authored when the story is
/// genuinely a coherent assortment from one shop. This keeps a visual card
/// variant from quietly turning a mixed editorial story into fake inventory.
struct MerchantCollectionPresentation: Hashable {
    let storyID: String
    let merchantID: String
    let productCount: Int
    let coverProductID: Int
    let coverImageIndex: Int
    let coverYOffset: CGFloat

    init(
        storyID: String,
        merchantID: String,
        productCount: Int,
        coverProductID: Int,
        coverImageIndex: Int,
        coverYOffset: CGFloat = 0
    ) {
        self.storyID = storyID
        self.merchantID = merchantID
        self.productCount = productCount
        self.coverProductID = coverProductID
        self.coverImageIndex = coverImageIndex
        self.coverYOffset = coverYOffset
    }

    func coverURL(from merchants: [SampleMerchant]) -> URL? {
        guard let merchant = merchants.first(where: { $0.id == merchantID }),
              let product = merchant.products.first(where: { $0.id == coverProductID }) else {
            return nil
        }
        let images = product.allImageURLs.isEmpty
            ? [product.imageURL].compactMap { $0 }
            : product.allImageURLs
        guard !images.isEmpty else { return nil }
        let source = images[min(coverImageIndex, images.count - 1)]
        let normalized = source.hasPrefix("//") ? "https:\(source)" : source
        return URL(string: normalized)
    }
}

enum MerchantCollectionCatalog {
    /// High-confidence buyer matches backed by the canonical catalog fixtures.
    /// Four-up cards preserve more of the lifestyle cover; six-up is reserved
    /// for merchants with a genuinely broader assortment.
    private static let authoredPresentations: [MerchantCollectionPresentation] = [
        .init(
            storyID: "discovery-nocs-field-kit",
            merchantID: "nocs",
            productCount: 2,
            coverProductID: 10432692846871,
            coverImageIndex: 1
        ),
        .init(
            storyID: "discovery-fellow-coffee-workflow",
            merchantID: "fellow",
            productCount: 2,
            coverProductID: 2055410221171,
            coverImageIndex: 1
        ),
        .init(
            storyID: "discovery-house-of-leon-reading-room",
            merchantID: "house-of-leon",
            productCount: 2,
            coverProductID: 7873592721581,
            coverImageIndex: 1
        ),
        .init(
            storyID: "discovery-draw-down-type-books",
            merchantID: "draw-down",
            productCount: 3,
            coverProductID: 7804062892286,
            coverImageIndex: 1
        ),
        .init(
            storyID: "andreas-lange-routine",
            merchantID: "lange-hair",
            productCount: 4,
            coverProductID: 4804878434404,
            coverImageIndex: 1
        ),
        .init(
            storyID: "andreas-minimal-comfort",
            merchantID: "comfrt",
            productCount: 4,
            coverProductID: 7287683743788,
            coverImageIndex: 1
        ),
        .init(
            storyID: "kyle-1890-collabs",
            merchantID: "kith",
            productCount: 4,
            coverProductID: 8286509564032,
            coverImageIndex: 1
        ),
        .init(
            storyID: "kyle-braided-bostons",
            merchantID: "kith",
            productCount: 4,
            coverProductID: 8286022762624,
            coverImageIndex: 1
        ),
        .init(
            storyID: "kyle-argizari-lighting",
            merchantID: "city-lights-sf",
            productCount: 6,
            coverProductID: 8568483807399,
            coverImageIndex: 1
        ),
        .init(
            storyID: "tobi-xbloom-system",
            merchantID: "xbloom",
            productCount: 4,
            coverProductID: 8424667807968,
            coverImageIndex: 1
        ),
        .init(
            storyID: "tobi-manmade-basics",
            merchantID: "manmade",
            productCount: 4,
            coverProductID: 8829694050617,
            coverImageIndex: 1
        ),
        .init(
            storyID: "tobi-wet-shave",
            merchantID: "henson-shaving",
            productCount: 4,
            coverProductID: 7234770337872,
            coverImageIndex: 2
        ),
        .init(
            storyID: "tobi-sim-racing",
            merchantID: "moza-racing",
            productCount: 4,
            coverProductID: 10209094500672,
            coverImageIndex: 2,
            coverYOffset: -142
        ),
        .init(
            storyID: "katarina-rick-owens",
            merchantID: "svrn-rick-owens",
            productCount: 4,
            coverProductID: 15632596205641,
            coverImageIndex: 1
        ),
        .init(
            storyID: "katarina-silver",
            merchantID: "vitaly",
            productCount: 4,
            coverProductID: 4415294537803,
            coverImageIndex: 2
        ),
        .init(
            storyID: "katarina-black-swim",
            merchantID: "matteau",
            productCount: 4,
            coverProductID: 9025373044958,
            coverImageIndex: 1
        ),
        .init(
            storyID: "katarina-rhode-routine",
            merchantID: "rhode",
            productCount: 6,
            coverProductID: 8070391660782,
            // The first three entries are duplicate packshots. This is
            // Rhode's official mobile lifestyle still for Glazing Milk.
            coverImageIndex: 4
        ),
        .init(
            storyID: "edit-wash-day-reset",
            merchantID: "ceremonia",
            productCount: 4,
            coverProductID: 15369056321905,
            // Use the single-frame wash-day lifestyle still. Index 1 is a
            // four-panel campaign collage that competes with the card's own
            // product grid and creates an unintended grid-on-grid treatment.
            coverImageIndex: 3
        ),
    ]

    static var presentations: [MerchantCollectionPresentation] {
        authoredPresentations + HypothesisShelfCatalog.merchantCollectionPresentations
    }

    static func presentation(for storyID: String) -> MerchantCollectionPresentation? {
        presentations.first { $0.storyID == storyID }
    }
}

/// Central mapping between Shop merchant identifiers and the official,
/// normalized white wordmarks bundled by `sync_merchant_wordmarks.py`.
enum MerchantBrandAssets {
    private static let aliases: [String: String] = [
        "nocs": "nocs-provisions",
        "moma": "moma-design-store",
        "svrn-rick-owens": "svrn",
        "feature-salomon": "feature",
        "extra-butter-salomon": "extra-butter",
    ]

    /// Storefront scraping can surface payment sprites or campaign art near
    /// the word "logo". These brands intentionally use a clean native text
    /// treatment until an official reusable wordmark is verified.
    private static let textFallbackOnly: Set<String> = [
        "standards-manual",
    ]

    static func hasVerifiedBundledWordmark(for merchantID: String) -> Bool {
        let assetID = aliases[merchantID] ?? merchantID
        return !merchantID.hasPrefix("shelf-shop-")
            && !textFallbackOnly.contains(assetID)
    }

    static func wordmarkName(for merchantID: String) -> String {
        let assetID = aliases[merchantID] ?? merchantID
        return "merchant-wordmark-\(assetID)"
    }
}
