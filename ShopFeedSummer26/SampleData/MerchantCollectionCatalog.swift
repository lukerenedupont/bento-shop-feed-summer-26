import SwiftUI

/// Background media must declare why it qualifies as lifestyle content.
/// Catalog packshots, packaging, grids, and promotional composites have no
/// valid role and therefore cannot enter the full-bleed rendering path.
enum FeedBackgroundMediaRole: String, Hashable {
    case merchantPost
    case inContext
    case wornOrUsed
    case editorial
}

/// An explicit cover decision for an editorial feed story. Product inventory
/// remains sourced from the buyer's shelf; this layer only decides which of
/// those real images is strong enough to become full-bleed media.
struct FeedCoverPresentation {
    let storyID: String
    let merchantID: String
    let productID: Int
    let imageIndex: Int
    let mediaRole: FeedBackgroundMediaRole
    let alignment: Alignment
    let yOffset: CGFloat
    let scale: CGFloat
    let textScrimOpacity: Double

    init(
        storyID: String,
        merchantID: String,
        productID: Int,
        imageIndex: Int = 0,
        mediaRole: FeedBackgroundMediaRole,
        alignment: Alignment = .center,
        yOffset: CGFloat = 0,
        scale: CGFloat = 1,
        textScrimOpacity: Double = 0.48
    ) {
        self.storyID = storyID
        self.merchantID = merchantID
        self.productID = productID
        self.imageIndex = imageIndex
        self.mediaRole = mediaRole
        self.alignment = alignment
        self.yOffset = yOffset
        self.scale = scale
        self.textScrimOpacity = textScrimOpacity
    }

    func coverURL(from merchants: [SampleMerchant]) -> URL? {
        guard let merchant = merchants.first(where: { $0.id == merchantID }),
              let product = merchant.products.first(where: { $0.id == productID }) else {
            return nil
        }
        let images = product.allImageURLs.isEmpty
            ? [product.imageURL].compactMap { $0 }
            : product.allImageURLs
        guard !images.isEmpty else { return nil }
        let source = images[min(imageIndex, images.count - 1)]
        let normalized = source.hasPrefix("//") ? "https:\(source)" : source
        return URL(string: normalized)
    }
}

enum FeedCoverCatalog {
    private static let fallbackImagesByTopic: [String: [String]] = [
        "living": [
            "cover-sculptural-mirrors",
            "cover-tabletop-objects",
            "cover-design-for-kids",
        ],
        "style": ["cover-trail-to-street", "cover-birding"],
        "wellness": ["cover-scalp-care", "cover-birding"],
        "morning": ["cover-coffee-counter", "cover-tabletop-objects"],
        "outdoors": ["cover-birding", "cover-trail-to-street"],
        "design": ["cover-material-study", "cover-sculptural-mirrors"],
    ]

    private static let universalFallbackImages = [
        "cover-sculptural-mirrors",
        "cover-coffee-counter",
        "cover-tabletop-objects",
        "cover-trail-to-street",
        "cover-scalp-care",
        "cover-birding",
        "cover-design-for-kids",
        "cover-material-study",
    ]

    /// Luke's first authored pass. Every image is a real product from the
    /// corresponding buyer shelf and has been visually checked for overlays,
    /// promotional copy, and a useful full-height crop.
    private static let authoredPresentations: [FeedCoverPresentation] = [
        .init(
            storyID: "shelf-luke-1-modern-bathroom-fixtures",
            merchantID: "shelf-shop-upton-ff049dd",
            productID: 3391803343539049754,
            mediaRole: .inContext,
            alignment: .center,
            textScrimOpacity: 0.56
        ),
        .init(
            storyID: "shelf-luke-2-sculptural-living-room-pieces",
            merchantID: "shelf-shop-the-oblist-02fd47c",
            productID: 1791399064416116685,
            mediaRole: .editorial,
            alignment: .center,
            textScrimOpacity: 0.42
        ),
        .init(
            storyID: "shelf-luke-11-neutral-activewear-essentials",
            merchantID: "shelf-shop-alo-yoga-561ac5f",
            productID: 5072467516453192554,
            mediaRole: .wornOrUsed,
            alignment: .top,
            textScrimOpacity: 0.48
        ),
    ]

    private static let presentationsByStoryID = Dictionary(
        uniqueKeysWithValues: authoredPresentations.map { ($0.storyID, $0) }
    )

    static func presentation(for story: FeedStory) -> FeedCoverPresentation? {
        presentationsByStoryID[story.id]
    }

    /// Guarantees a vetted lifestyle/editorial image behind every feed card.
    /// Product- and merchant-specific authored media still wins; this is the
    /// final visual fallback instead of a flat color or enlarged PDP image.
    static func fallbackImageName(for story: FeedStory) -> String {
        fallbackImageName(stableID: story.id, topicKeys: Array(story.topicKeys))
    }

    static func fallbackImageName(stableID: String, topicKeys: [String] = []) -> String {
        let topicPriority = ["living", "style", "wellness", "morning", "outdoors", "design"]
        let topic = topicPriority.first { topicKeys.contains($0) }
        let candidates = topic.flatMap { fallbackImagesByTopic[$0] } ?? universalFallbackImages
        let stableSeed = stableID.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        return candidates[abs(stableSeed) % candidates.count]
    }
}

/// A collection-level merchant treatment is only authored when the story is
/// genuinely a coherent assortment from one shop. This keeps a visual card
/// variant from quietly turning a mixed editorial story into fake inventory.
struct MerchantCollectionPresentation: Hashable {
    let storyID: String
    /// Owns the exact buyer-profile assortment rendered in the product grid.
    let merchantID: String
    /// Optional canonical merchant record used only for verified identity,
    /// lifestyle media, and the store destination.
    let brandMerchantID: String?
    let productCount: Int
    let coverProductID: Int
    let coverImageIndex: Int
    let lifestyleCoverURL: String?
    let coverYOffset: CGFloat
    /// Only authored lifestyle media is allowed to fill the card. Generated
    /// catalog packshots often contain labels, banners, or baked-in copy.
    let usesImageCover: Bool

    init(
        storyID: String,
        merchantID: String,
        brandMerchantID: String? = nil,
        productCount: Int,
        coverProductID: Int,
        coverImageIndex: Int,
        lifestyleCoverURL: String? = nil,
        coverYOffset: CGFloat = 0,
        usesImageCover: Bool = true
    ) {
        self.storyID = storyID
        self.merchantID = merchantID
        self.brandMerchantID = brandMerchantID
        self.productCount = productCount
        self.coverProductID = coverProductID
        self.coverImageIndex = coverImageIndex
        self.lifestyleCoverURL = lifestyleCoverURL
        self.coverYOffset = coverYOffset
        self.usesImageCover = usesImageCover
    }

    func coverURL(from merchants: [SampleMerchant]) -> URL? {
        if let lifestyleCoverURL {
            let normalized = lifestyleCoverURL.hasPrefix("//")
                ? "https:\(lifestyleCoverURL)"
                : lifestyleCoverURL
            return URL(string: normalized)
        }
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
